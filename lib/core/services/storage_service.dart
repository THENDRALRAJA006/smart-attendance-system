// ============================================================
// SmartAttend — Storage Service (Secure Storage)
// ============================================================

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

class StorageService extends GetxService {
  static StorageService get to => Get.find<StorageService>();

  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static const String _tokenKey = 'sa_jwt_token';
  static const String _refreshTokenKey = 'sa_jwt_refresh_token';
  static const String _roleKey = 'sa_user_role';
  static const String _userKey = 'sa_user_data';

  // ==========================================================
  // ACCESS TOKEN
  // ==========================================================

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  // ==========================================================
  // REFRESH TOKEN
  // ==========================================================

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  // ==========================================================
  // ROLE
  // ==========================================================

  Future<void> saveRole(String role) async {
    await _secureStorage.write(
      key: _roleKey,
      value: role,
    );
  }

  Future<String?> getRole() async {
    return await _secureStorage.read(
      key: _roleKey,
    );
  }

  // ==========================================================
  // USER DATA
  // ==========================================================

  Future<void> saveUser(
    Map<String, dynamic> user,
  ) async {
    await _secureStorage.write(
      key: _userKey,
      value: jsonEncode(user),
    );
  }

  Future<Map<String, dynamic>?> getUser() async {
    final data = await _secureStorage.read(
      key: _userKey,
    );

    if (data == null) return null;

    return jsonDecode(data)
        as Map<String, dynamic>;
  }

  // ==========================================================
  // LOGIN STATUS
  // ==========================================================

  Future<bool> isLoggedIn() async {
    final token = await getToken();

    return token != null &&
        token.isNotEmpty;
  }

  // ==========================================================
  // CLEAR ALL
  // ==========================================================

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
