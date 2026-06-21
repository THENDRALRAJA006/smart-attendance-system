// ============================================================
// SmartAttend — BLE Service
// Scans for ESP32 classroom beacons and checks RSSI
// ============================================================

import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../constants/app_constants.dart';

class BleService extends GetxService {
  static BleService get to => Get.find();

  // ─── State ──────────────────────────────────────────────
  final RxList<DetectedClassroom> detectedClassrooms = <DetectedClassroom>[].obs;
  final RxBool isScanning = false.obs;
  final Rx<BleStatus> status = BleStatus.unknown.obs;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToAdapterState();
  }

  // ─── Listen to adapter ──────────────────────────────────
  void _listenToAdapterState() {
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        status.value = BleStatus.on;
      } else {
        status.value = BleStatus.off;
        stopScan();
      }
    });
  }

  // ─── Start Scan ─────────────────────────────────────────
  Future<void> startScan() async {
    if (isScanning.value) return;

    detectedClassrooms.clear();
    isScanning.value = true;

    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: AppConstants.bleScanDuration),
        androidUsesFineLocation: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName;
          if (name.isNotEmpty && _isSmartAttendBeacon(name)) {
            dev.log(
              '[BLE_DETECTION] SmartAttend beacon detected: name=$name, '
              'remoteId=${result.device.remoteId.str}, rssi=${result.rssi} dBm, '
              'serviceUuids=${result.advertisementData.serviceUuids}',
              name: 'BleService',
            );
            final classroom = DetectedClassroom(
              name: name,
              rssi: result.rssi,
              deviceId: result.device.remoteId.str,
              isInRange: result.rssi > AppConstants.rssiThreshold,
            );
            // Update or add
            final idx = detectedClassrooms.indexWhere(
              (c) => c.deviceId == classroom.deviceId,
            );
            if (idx >= 0) {
              detectedClassrooms[idx] = classroom;
            } else {
              detectedClassrooms.add(classroom);
            }
          }
        }
      });

      // Auto-stop after scan duration
      Future.delayed(
        Duration(seconds: AppConstants.bleScanDuration),
        () {
          stopScan();
          dev.log(
            '[BLE_DETECTION] Scan finished. Total detected classrooms: ${detectedClassrooms.length}',
            name: 'BleService',
          );
          for (final c in detectedClassrooms) {
            dev.log(
              '  - Classroom: name=${c.name}, deviceId/remoteId=${c.deviceId}, rssi=${c.rssi} dBm, isInRange=${c.isInRange}',
              name: 'BleService',
            );
          }
        },
      );
    } catch (e) {
      isScanning.value = false;
      rethrow;
    }
  }

  // ─── Stop Scan ──────────────────────────────────────────
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    isScanning.value = false;
  }

  // ─── Check if it's our beacon ───────────────────────────
  bool _isSmartAttendBeacon(String name) {
    // Case-insensitive check — supports any ESP32 naming convention:
    //   CLASSROOM_A101, Lab_CS01, SMART_ATTEND_B201, SmartAttend_Hall1, etc.
    final upperName = name.toUpperCase();
    return upperName.startsWith('CLASSROOM_') ||
        upperName.startsWith('LAB_') ||
        upperName.startsWith('SMART_ATTEND') ||
        upperName.startsWith('SMARTATTEND') ||
        upperName.startsWith('SA_');
  }

  // ─── Get best classroom (strongest in-range signal) ─────
  DetectedClassroom? getBestClassroom() {
    final inRange = detectedClassrooms.where((c) => c.isInRange).toList();
    if (inRange.isEmpty) return null;
    inRange.sort((a, b) => b.rssi.compareTo(a.rssi));
    return inRange.first;
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    super.onClose();
  }
}

// ─── BLE Status Enum ────────────────────────────────────────
enum BleStatus { unknown, on, off }

// ─── Detected Classroom Model ───────────────────────────────
class DetectedClassroom {
  final String name;
  final int rssi;
  final String deviceId;
  final bool isInRange;

  DetectedClassroom({
    required this.name,
    required this.rssi,
    required this.deviceId,
    required this.isInRange,
  });

  String get signalLabel => AppConstants.rssiLabel(rssi);
  int get signalBars => AppConstants.rssiStrength(rssi);
}
