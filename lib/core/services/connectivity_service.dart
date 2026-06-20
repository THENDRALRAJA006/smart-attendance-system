// ============================================================
// SmartAttend — Connectivity Service
// Detects network state and exposes isOnline observable
// ============================================================

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find<ConnectivityService>();

  final RxBool isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    // Check current state immediately
    final results = await Connectivity().checkConnectivity();
    isOnline.value = _isConnected(results);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final connected = _isConnected(results);
      if (connected != isOnline.value) {
        isOnline.value = connected;
        if (connected) {
          Get.snackbar(
            '✅ Back Online',
            'Internet connection restored.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
        } else {
          Get.snackbar(
            '⚠️ No Internet',
            'You are offline. Please check your connection.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
        }
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  /// Returns true if currently connected to the internet.
  bool get hasConnection => isOnline.value;

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
