// ============================================================
// SmartAttend — BLE Scanner Service (Production v3)
//
// Upgrades from v2:
//  - RSSI rolling window increased: 5 → 8 readings
//  - Spike rejection: ignore readings > 15 dBm from running avg
//  - Auto-reconnect: if scan stops unexpectedly, restart within 3s
//  - Bluetooth state monitoring: warn user if BT turned off
//  - Status enum: scanning / connected / reconnecting / off
//  - Dynamic threshold: still base -80 dBm (already optimal)
// ============================================================

import 'dart:async';
import 'dart:collection';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_constants.dart';

// ─── BLE Status Enum ─────────────────────────────────────────
enum BleStatus { idle, scanning, reconnecting, bluetoothOff, permissionDenied }

class DetectedClassroom {
  final String name;
  final String deviceId;
  final int rssi;          // Averaged RSSI (not raw)
  final int rawRssi;       // Last raw RSSI reading
  final bool isInRange;
  final String signalLabel;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int sampleCount;   // Number of readings averaged

  DetectedClassroom({
    required this.name,
    required this.deviceId,
    required this.rssi,
    required this.rawRssi,
    required this.isInRange,
    required this.signalLabel,
    required this.firstSeen,
    required this.lastSeen,
    required this.sampleCount,
  });

  DetectedClassroom copyWith({int? rssi, int? rawRssi, bool? isInRange, String? signalLabel, DateTime? lastSeen, int? sampleCount}) {
    return DetectedClassroom(
      name: name,
      deviceId: deviceId,
      rssi: rssi ?? this.rssi,
      rawRssi: rawRssi ?? this.rawRssi,
      isInRange: isInRange ?? this.isInRange,
      signalLabel: signalLabel ?? this.signalLabel,
      firstSeen: firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }
}

// ─── RSSI Buffer with Spike Rejection ─────────────────────────
class _RssiBuffer {
  // v3: window increased to 8, spike rejection threshold = 15 dBm
  final int maxSize;
  static const int _spikeThreshold = 15; // dBm

  final Queue<int> _buffer = Queue();
  DateTime firstSeen = DateTime.now();
  DateTime lastSeen = DateTime.now();
  String name;
  String deviceId;

  _RssiBuffer({required this.maxSize, required this.name, required this.deviceId});

  void add(int rssi) {
    // Spike rejection: if we have readings and this one is > threshold away from avg, skip it
    if (_buffer.isNotEmpty) {
      final avg = average;
      if ((rssi - avg).abs() > _spikeThreshold) {
        // Spike detected — update timestamp but don't add to buffer
        lastSeen = DateTime.now();
        return;
      }
    }
    _buffer.addLast(rssi);
    if (_buffer.length > maxSize) _buffer.removeFirst();
    lastSeen = DateTime.now();
  }

  int get average {
    if (_buffer.isEmpty) return -100;
    return (_buffer.reduce((a, b) => a + b) / _buffer.length).round();
  }

  int get latest => _buffer.isNotEmpty ? _buffer.last : -100;

  int get sampleCount => _buffer.length;

  bool get isStable {
    final ageMs = lastSeen.difference(firstSeen).inMilliseconds;
    return sampleCount >= 2 || ageMs >= AppConstants.rssiStableMs;
  }
}

class BleService extends GetxService {
  static BleService get to => Get.find();

  // ─── Observable State ─────────────────────────────────────
  final RxBool isScanning = false.obs;
  final RxList<DetectedClassroom> detectedClassrooms = <DetectedClassroom>[].obs;
  final Rx<BleStatus> bleStatus = BleStatus.idle.obs;
  final RxString statusMessage = ''.obs;

  // ─── Internal State ────────────────────────────────────────
  final Map<String, _RssiBuffer> _rssiBuffers = {};
  final Map<String, DateTime> _lastDetected = {};

  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _btStateSubscription;

  // Auto-reconnect
  Timer? _reconnectTimer;
  bool _userRequestedStop = false;
  bool _autoReconnectEnabled = false;

  // v3: window size increased from 5 to 8
  static const int _rssiWindowSize = 8;

  @override
  void onInit() {
    super.onInit();

    // Monitor BT scanning state
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      isScanning.value = scanning;

      // Auto-reconnect: if scanning stopped unexpectedly while we want it running
      if (!scanning && _autoReconnectEnabled && !_userRequestedStop) {
        bleStatus.value = BleStatus.reconnecting;
        statusMessage.value = 'Reconnecting...';
        _scheduleReconnect();
      } else if (!scanning && _userRequestedStop) {
        bleStatus.value = BleStatus.idle;
        statusMessage.value = '';
      }
    });

    // Monitor Bluetooth adapter state
    _btStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        bleStatus.value = BleStatus.bluetoothOff;
        statusMessage.value = 'Bluetooth is off. Please turn it on.';
        _autoReconnectEnabled = false;
        detectedClassrooms.clear();
      } else if (state == BluetoothAdapterState.on) {
        if (bleStatus.value == BleStatus.bluetoothOff) {
          statusMessage.value = 'Bluetooth is back on.';
          // If we were scanning before, try to restart
          if (_autoReconnectEnabled) _scheduleReconnect();
        }
      }
    });
  }

  // ─── Start Scan ───────────────────────────────────────────
  Future<void> startScan({bool autoReconnect = false}) async {
    _autoReconnectEnabled = autoReconnect;
    _userRequestedStop = false;

    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      bleStatus.value = BleStatus.permissionDenied;
      statusMessage.value = 'Bluetooth and Location permissions are required.';
      throw Exception('Bluetooth and Location permissions are required for scanning.');
    }

    detectedClassrooms.clear();
    _rssiBuffers.clear();
    _lastDetected.clear();
    await stopScan(userRequested: false);

    bleStatus.value = BleStatus.scanning;
    statusMessage.value = 'Scanning for classrooms...';

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: AppConstants.bleScanDuration),
      androidUsesFineLocation: true,
    );

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) => _processResults(results),
      onError: (e) {
        isScanning.value = false;
        if (_autoReconnectEnabled && !_userRequestedStop) {
          _scheduleReconnect();
        }
      },
    );
  }

  // ─── Auto-Reconnect Scheduler ─────────────────────────────
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_userRequestedStop) return;
      try {
        bleStatus.value = BleStatus.reconnecting;
        statusMessage.value = 'Reconnecting...';
        await startScan(autoReconnect: true);
      } catch (_) {
        // Will retry again on next state change
      }
    });
  }

  // ─── Process Scan Results with RSSI Averaging + Spike Rejection ─
  void _processResults(List<ScanResult> results) {
    final now = DateTime.now();

    for (final result in results) {
      final String name = result.advertisementData.advName;
      final String upperName = name.toUpperCase();

      // Filter SmartAttend beacons
      if (!upperName.startsWith(AppConstants.bleServicePrefix) &&
          !upperName.contains('CLASSROOM')) {
        continue;
      }

      final String deviceId = result.device.remoteId.str;
      final int rawRssi = result.rssi;

      // Initialize buffer if needed (v3: window size = 8)
      if (!_rssiBuffers.containsKey(deviceId)) {
        _rssiBuffers[deviceId] = _RssiBuffer(
          maxSize: _rssiWindowSize,
          name: name,
          deviceId: deviceId,
        );
        _rssiBuffers[deviceId]!.firstSeen = now;
      }

      // Add reading to buffer (spike rejection happens inside _RssiBuffer.add)
      _rssiBuffers[deviceId]!.add(rawRssi);
      _rssiBuffers[deviceId]!.name = name.isNotEmpty ? name : _rssiBuffers[deviceId]!.name;
    }

    // Build stable classroom list from buffers
    final Map<String, DetectedClassroom> uniqueClassrooms = {};

    for (final entry in _rssiBuffers.entries) {
      final buf = entry.value;
      if (!buf.isStable) continue; // Not enough readings yet

      final avgRssi = buf.average;
      final bool isInRange = avgRssi >= AppConstants.rssiThreshold;
      final String signalLabel = AppConstants.rssiLabel(avgRssi);

      uniqueClassrooms[entry.key] = DetectedClassroom(
        name: buf.name,
        deviceId: entry.key,
        rssi: avgRssi,
        rawRssi: buf.latest,
        isInRange: isInRange,
        signalLabel: signalLabel,
        firstSeen: buf.firstSeen,
        lastSeen: buf.lastSeen,
        sampleCount: buf.sampleCount,
      );
    }

    // Update status message with detection info
    final inRangeCount = uniqueClassrooms.values.where((c) => c.isInRange).length;
    if (uniqueClassrooms.isNotEmpty) {
      bleStatus.value = BleStatus.scanning;
      statusMessage.value = inRangeCount > 0
          ? '$inRangeCount classroom${inRangeCount > 1 ? "s" : ""} in range'
          : '${uniqueClassrooms.length} beacon${uniqueClassrooms.length > 1 ? "s" : ""} detected (out of range)';
    }

    // Sort: In Range first, then by averaged signal strength
    final sortedList = uniqueClassrooms.values.toList()
      ..sort((a, b) {
        if (a.isInRange && !b.isInRange) return -1;
        if (!a.isInRange && b.isInRange) return 1;
        return b.rssi.compareTo(a.rssi);
      });

    detectedClassrooms.assignAll(sortedList);
  }

  // ─── Get Best In-Range Classroom ─────────────────────────
  DetectedClassroom? get bestClassroom {
    final inRange = detectedClassrooms.where((c) => c.isInRange).toList();
    if (inRange.isEmpty) return null;
    inRange.sort((a, b) => b.rssi.compareTo(a.rssi));
    return inRange.first;
  }

  // ─── Stop Scan ────────────────────────────────────────────
  Future<void> stopScan({bool userRequested = true}) async {
    if (userRequested) {
      _userRequestedStop = true;
      _autoReconnectEnabled = false;
      _reconnectTimer?.cancel();
      bleStatus.value = BleStatus.idle;
      statusMessage.value = '';
    }
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    isScanning.value = false;
  }

  @override
  void onClose() {
    _userRequestedStop = true;
    _reconnectTimer?.cancel();
    _isScanningSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _btStateSubscription?.cancel();
    super.onClose();
  }
}
