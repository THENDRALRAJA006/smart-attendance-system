// ============================================================
// SmartAttend — BLE Scanner Service (v4)
// Scans for classroom beacons and filters by SMART_ATTEND prefix
// ============================================================

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_constants.dart';

class DetectedClassroom {
  final String name;
  final String deviceId; // MAC address / device ID
  final int rssi;
  final bool isInRange;
  final String signalLabel;

  DetectedClassroom({
    required this.name,
    required this.deviceId,
    required this.rssi,
    required this.isInRange,
    required this.signalLabel,
  });
}

class BleService extends GetxService {
  static BleService get to => Get.find();

  // Observable state
  final RxBool isScanning = false.obs;
  final RxList<DetectedClassroom> detectedClassrooms = <DetectedClassroom>[].obs;
  
  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;

  @override
  void onInit() {
    super.onInit();
    // Listen to native scanning status updates
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      isScanning.value = scanning;
    });
  }

  // ─── Start Scan ───────────────────────────────────────────
  Future<void> startScan() async {
    // 1. Request required permissions on Android/iOS
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      throw Exception('Bluetooth and Location permissions are required for scanning.');
    }

    // 2. Clear previous results and stop any active scan
    detectedClassrooms.clear();
    await stopScan();

    // 3. Start native scanning with a timeout
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: AppConstants.bleScanDuration),
      androidUsesFineLocation: true,
    );

    // 4. Subscribe to scan results
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        final Map<String, DetectedClassroom> uniqueClassrooms = {};

        for (var result in results) {
          final String name = result.advertisementData.advName;
          final String uppercaseName = name.toUpperCase();
          
          // Filter beacons by name (starts with SMART_ATTEND or contains CLASSROOM)
          if (uppercaseName.startsWith(AppConstants.bleServicePrefix) || 
              uppercaseName.contains('CLASSROOM')) {
            
            final int rssi = result.rssi;
            final String deviceId = result.device.remoteId.str;
            final bool isInRange = rssi >= AppConstants.rssiThreshold;
            final String signalLabel = AppConstants.rssiLabel(rssi);

            // Deduplicate: keep the one with the stronger RSSI
            if (!uniqueClassrooms.containsKey(deviceId) || 
                uniqueClassrooms[deviceId]!.rssi < rssi) {
              uniqueClassrooms[deviceId] = DetectedClassroom(
                name: name,
                deviceId: deviceId,
                rssi: rssi,
                isInRange: isInRange,
                signalLabel: signalLabel,
              );
            }
          }
        }

        // Sort: In Range first, then by signal strength descending
        final sortedList = uniqueClassrooms.values.toList()
          ..sort((a, b) {
            if (a.isInRange && !b.isInRange) return -1;
            if (!a.isInRange && b.isInRange) return 1;
            return b.rssi.compareTo(a.rssi);
          });

        detectedClassrooms.assignAll(sortedList);
      },
      onError: (e) {
        isScanning.value = false;
      },
    );
  }

  // ─── Stop Scan ────────────────────────────────────────────
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    isScanning.value = false;
  }

  @override
  void onClose() {
    _isScanningSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    super.onClose();
  }
}
