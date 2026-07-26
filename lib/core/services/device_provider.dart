// ============================================================
// SmartAttend — DeviceProvider (v7)
//
// GetX controller that manages the reactive device binding state.
// Wraps API calls to the backend /device/* endpoints.
//
// Used by:
//  • AuthController  — check device status on login
//  • AttendanceVerificationScreen — verify signature before marking attendance
// ============================================================

import 'dart:developer' as dev;

import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';

import '../network/api_client.dart';
import 'device_service.dart';

/// Possible states for this device relative to the student's account.
enum DeviceBindingStatus {
  unknown,
  notRegistered,
  active,
  inactive,
  pendingTransfer,
  mismatch,
}

class DeviceProvider extends GetxController {
  // ─── Singleton accessor ─────────────────────────────────────
  static DeviceProvider get to => Get.find<DeviceProvider>();

  // ─── Reactive state ─────────────────────────────────────────
  final status       = DeviceBindingStatus.unknown.obs;
  final isLoading    = false.obs;
  final errorMessage = ''.obs;

  // ─── Dependencies ───────────────────────────────────────────
  late final DeviceService _device;
  late final ApiClient     _api;

  @override
  void onInit() {
    super.onInit();
    _device = DeviceService.to;
    _api    = ApiClient.to;
  }

  // ──────────────────────────────────────────────────────────────
  // DEVICE REGISTRATION (called on login if no device is bound)
  // ──────────────────────────────────────────────────────────────

  /// Register this device with the backend.
  /// Returns true on success.
  Future<bool> registerDevice(int studentId) async {
    isLoading.value    = true;
    errorMessage.value = '';
    try {
      final info = await _device.collect();
      await _api.post('/device/register', data: {
        'student_id':        studentId,
        'installation_uuid': info.installationUuid,
        'android_id':        info.androidId,
        'app_set_id':        info.appSetId,
        'public_key':        info.publicKeyPem,
        'manufacturer':      info.manufacturer,
        'brand':             info.brand,
        'model':             info.model,
        'android_version':   info.androidVersion,
        'app_version':       info.appVersion,
      });
      status.value = DeviceBindingStatus.active;
      dev.log('[DeviceProvider] Device registered OK', name: 'DeviceProvider');
      return true;
    } on dio.DioException catch (e) {
      errorMessage.value = e.response?.data?['detail'] ?? e.message ?? 'Registration failed';
      dev.log('[DeviceProvider] registerDevice error: ${errorMessage.value}', name: 'DeviceProvider');
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // DEVICE VERIFICATION (called before marking attendance)
  // Signs a fresh nonce with the Android Keystore key.
  // ──────────────────────────────────────────────────────────────

  /// Verify the device signature against the backend.
  /// Returns true if the signature is valid and the device is active.
  Future<bool> verifyDeviceForAttendance(int studentId) async {
    isLoading.value    = true;
    errorMessage.value = '';
    try {
      final info      = await _device.collect();
      final nonce     = DateTime.now().millisecondsSinceEpoch.toString();
      final payload   = '$studentId:$nonce';
      final signature = await _device.sign(payload);

      if (signature == null) {
        errorMessage.value = 'Device signature failed. Try restarting the app.';
        return false;
      }

      final resp = await _api.post('/device/verify', data: {
        'student_id':        studentId,
        'installation_uuid': info.installationUuid,
        'android_id':        info.androidId,
        'signed_payload':    payload,
        'signature':         signature,
      });

      final data   = resp.data as Map<String, dynamic>? ?? {};
      final ok     = data['verified'] == true;
      status.value = ok
          ? DeviceBindingStatus.active
          : DeviceBindingStatus.mismatch;

      if (!ok) {
        errorMessage.value = data['detail'] ??
            data['message'] ??
            'Device verification failed.';
      }
      return ok;
    } on dio.DioException catch (e) {
      errorMessage.value = e.response?.data?['detail'] ?? e.message ?? 'Verification failed';
      dev.log('[DeviceProvider] verify error: ${errorMessage.value}', name: 'DeviceProvider');
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // RESET (called on logout)
  // ──────────────────────────────────────────────────────────────

  void reset() {
    status.value       = DeviceBindingStatus.unknown;
    isLoading.value    = false;
    errorMessage.value = '';
  }
}
