// ============================================================
// SmartAttend — Camera Service
// Handles face capture for registration and verification
// ============================================================

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraService extends GetxService {
  static CameraService get to => Get.find();

  CameraController? controller;
  List<CameraDescription> _cameras = [];
  final RxBool isInitialized = false.obs;
  final RxBool isProcessing = false.obs;

  // ─── Initialize camera (front-facing) ───────────────────
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw Exception('No cameras found on device');

    // Prefer front camera
    final frontCamera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();
    isInitialized.value = true;
  }

  // ─── Capture and return file ────────────────────────────
  Future<File> captureImage({bool compress = true}) async {
    if (controller == null || !controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    if (isProcessing.value) throw Exception('Already processing');

    isProcessing.value = true;
    try {
      final xFile = await controller!.takePicture();
      final file = File(xFile.path);

      if (!compress) {
        return file;
      }

      // Compress image for faster upload
      final compressed = await _compressImage(file);
      return compressed;
    } finally {
      isProcessing.value = false;
    }
  }

  // ─── Compress image (max 800px width) ───────────────────
  Future<File> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    final resized = img.copyResize(image, width: 800);
    final compressed = img.encodeJpg(resized, quality: 85);

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath)..writeAsBytesSync(compressed);
    return outFile;
  }

  // ─── Dispose ─────────────────────────────────────────────
  @override
  void onClose() {
    controller?.dispose();
    super.onClose();
  }

  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
    isInitialized.value = false;
  }
}
