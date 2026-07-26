// ============================================================
// SmartAttend — DeviceService (v7 + v8)
//
// Responsibilities:
//  • Collect Android device identifiers (ANDROID_ID, App Set ID, model, etc.)
//  • Generate and persist a stable installation UUID
//  • Sign challenge payloads via Android Keystore (EC P-256)
//  • Expose getAndroidId() for session-scoped device deduplication (v8)
//
// Used by:
//  • AuthController  — device registration / binding check on login
//  • AttendanceController — inject device_id into /attendance/mark
// ============================================================

import 'dart:developer' as dev;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Thin model carrying all identifiers and metadata for a device registration.
class DeviceInfo {
  final String installationUuid;
  final String androidId;
  final String? appSetId;
  final String? publicKeyPem;
  final String manufacturer;
  final String brand;
  final String model;
  final String androidVersion;
  final String appVersion;

  const DeviceInfo({
    required this.installationUuid,
    required this.androidId,
    this.appSetId,
    this.publicKeyPem,
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.androidVersion,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'installation_uuid': installationUuid,
        'android_id':        androidId,
        'app_set_id':        appSetId,
        'public_key':        publicKeyPem,
        'manufacturer':      manufacturer,
        'brand':             brand,
        'model':             model,
        'android_version':   androidVersion,
        'app_version':       appVersion,
      };
}

class DeviceService extends GetxService {
  // ─── Singleton accessor ─────────────────────────────────────
  static DeviceService get to => Get.find<DeviceService>();

  static const _kInstallUuidKey = 'smartattend_install_uuid';

  final _secureStorage  = const FlutterSecureStorage();
  final _deviceInfoPlugin = DeviceInfoPlugin();

  /// MethodChannel to the Kotlin KeystorePlugin.
  static const _keystoreChannel =
      MethodChannel('com.smartattend.app/keystore');

  // ─── Cached Android ID (populated on first call) ────────────
  String? _cachedAndroidId;

  // ──────────────────────────────────────────────────────────────
  // PUBLIC API
  // ──────────────────────────────────────────────────────────────

  /// Returns the Android ANDROID_ID for this device.
  /// Used by [AttendanceController] for session-scoped device dedup (v8).
  Future<String> getAndroidId() async {
    if (_cachedAndroidId != null) return _cachedAndroidId!;
    try {
      final info = await _deviceInfoPlugin.androidInfo;
      _cachedAndroidId = info.id; // ANDROID_ID
      return _cachedAndroidId!;
    } catch (e) {
      dev.log('[DeviceService] getAndroidId failed: $e', name: 'DeviceService');
      return '';
    }
  }

  /// Collect all device identifiers and metadata.
  /// Generates a stable installation UUID on first call (persisted in EncryptedSharedPreferences).
  Future<DeviceInfo> collect() async {
    final androidInfo  = await _deviceInfoPlugin.androidInfo;
    final packageInfo  = await PackageInfo.fromPlatform();
    final installUuid  = await _getOrCreateInstallUuid();
    final appSetId     = await _getAppSetId();
    final publicKeyPem = await _getOrCreatePublicKey();

    _cachedAndroidId = androidInfo.id;

    return DeviceInfo(
      installationUuid: installUuid,
      androidId:        androidInfo.id,
      appSetId:         appSetId,
      publicKeyPem:     publicKeyPem,
      manufacturer:     androidInfo.manufacturer,
      brand:            androidInfo.brand,
      model:            androidInfo.model,
      androidVersion:   androidInfo.version.release,
      appVersion:       packageInfo.version,
    );
  }

  /// Sign [payload] with the EC P-256 key in Android Keystore.
  /// Returns Base64-encoded DER signature, or null on failure.
  Future<String?> sign(String payload) async {
    try {
      final result = await _keystoreChannel.invokeMethod<String>(
        'sign',
        {'payload': payload},
      );
      return result;
    } on PlatformException catch (e) {
      dev.log('[DeviceService] sign() failed: ${e.message}', name: 'DeviceService');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Returns an existing stable UUID or generates a new one.
  /// Stored in EncryptedSharedPreferences — survives reinstalls on most devices.
  Future<String> _getOrCreateInstallUuid() async {
    final existing = await _secureStorage.read(key: _kInstallUuidKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = const Uuid().v4();
    await _secureStorage.write(key: _kInstallUuidKey, value: fresh);
    dev.log('[DeviceService] New install UUID: $fresh', name: 'DeviceService');
    return fresh;
  }

  /// Reads the Google App Set ID (per-device, per-Play-account scoped).
  /// Returns null gracefully if the plugin isn't available.
  Future<String?> _getAppSetId() async {
    try {
      // app_set_id plugin exposes a static getIdentifier() method
      final result = await const MethodChannel('plugins.flutter.io/app_set_id')
          .invokeMethod<String>('getIdentifier');
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Generates (or retrieves) the EC P-256 public key from Android Keystore.
  Future<String?> _getOrCreatePublicKey() async {
    try {
      final pem = await _keystoreChannel.invokeMethod<String>('getPublicKey');
      return pem;
    } on PlatformException catch (e) {
      dev.log(
        '[DeviceService] getPublicKey failed: ${e.message}',
        name: 'DeviceService',
      );
      return null;
    }
  }
}
