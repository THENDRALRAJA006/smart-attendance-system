// ============================================================
// SmartAttend — QR Verification Screen (Enterprise v2)
// Premium animated scanner → session preview → auto-advance
// QR is now mandatory step AFTER BLE
// v2: Removed tab UI, direct camera scanner, animated overlay
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../controllers/attendance_controller.dart';
// AppConstants removed — navigation handled inside markAttendanceQr()
import '../../core/theme/app_theme.dart';
import '../../widgets/biometric_progress_bar.dart';
import '../../widgets/qr_scanner_overlay.dart';

class QrVerificationScreen extends StatefulWidget {
  const QrVerificationScreen({super.key});

  @override
  State<QrVerificationScreen> createState() => _QrVerificationScreenState();
}

class _QrVerificationScreenState extends State<QrVerificationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final AttendanceController _attendance = Get.find<AttendanceController>();
  final ImagePicker _picker = ImagePicker();

  // ─── Scanner controller created in initState, not as a field ─
  // Creating it as a field causes "already running" when the screen
  // is rebuilt or returned to from another route.
  MobileScannerController? _scanCtrl;

  bool _processing = false;
  bool _scanSuccess = false;
  bool _scanError = false;
  bool _torchOn = false;
  String? _errorMessage;

  // Session info (shown after scan)
  Map<String, dynamic>? _sessionPreview;

  late AnimationController _entryController;
  late AnimationController _successController;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Create scanner controller fresh every time screen is opened
    _scanCtrl = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      autoStart: true,
    );

    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _successController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _entryFade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _successScale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _successController, curve: Curves.elasticOut));

    _entryController.forward();

    // Duplicate check at entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_attendance.alreadyMarked) _showAlreadyMarkedDialog();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_scanCtrl == null) return;
    if (state == AppLifecycleState.paused) {
      _scanCtrl!.stop();
    } else if (state == AppLifecycleState.resumed && !_processing && !_scanSuccess) {
      _scanCtrl!.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entryController.dispose();
    _successController.dispose();
    // Stop before dispose to avoid "already running" on re-entry
    _scanCtrl?.stop();
    _scanCtrl?.dispose();
    _scanCtrl = null;
    super.dispose();
  }

  // ─── Process Scanned QR ────────────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _scanSuccess) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    HapticFeedback.mediumImpact();
    await _processQrToken(barcode!.rawValue!);
  }

  // ─── Core QR Processing ────────────────────────────────────
  Future<void> _processQrToken(String token) async {
    if (_processing) return;
    setState(() { _processing = true; _errorMessage = null; });

    await _scanCtrl?.stop();

    // Optimistic success flash
    setState(() => _scanSuccess = true);
    _successController.forward(from: 0);
    HapticFeedback.heavyImpact();

    final ok = await _attendance.validateQrToken(token);

    if (!mounted) return;

    if (ok) {
      setState(() {
        _sessionPreview = {
          'subject_name':   _attendance.deepLinkSessionSubject.value,
          'classroom_name': _attendance.deepLinkSessionClassroom.value,
          'session_id':     _attendance.deepLinkSessionId.value,
        };
      });

      // Show preview briefly then mark attendance
      // markAttendanceQr() handles navigation to result screen internally
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await _attendance.markAttendanceQr();
      // Do NOT call Get.offAllNamed here — markAttendanceQr() does it
    } else {
      // Reset for retry
      setState(() {
        _scanSuccess = false;
        _scanError = true;
        _errorMessage = _attendance.error.value;
        _processing = false;
      });

      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() { _scanError = false; });
        await _scanCtrl?.start();
      }
    }
  }

  // ─── Upload QR Image ───────────────────────────────────────
  Future<void> _uploadQrImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final imagePath = picked.path;
      // Use a dedicated temporary controller for gallery image analysis
      MobileScannerController? tempCtrl;
      try {
        tempCtrl = MobileScannerController();
        final result = await tempCtrl.analyzeImage(imagePath);
        if (result == null || result.barcodes.isEmpty) {
          if (mounted) _showError('No QR code found in the selected image. Please try another image.');
          return;
        }
        final rawVal = result.barcodes.first.rawValue;
        if (rawVal == null) {
          if (mounted) _showError('Could not read QR code from image.');
          return;
        }
        await _processQrToken(rawVal);
      } finally {
        await tempCtrl?.stop();
        tempCtrl?.dispose();
      }
    } catch (e) {
      _showError('Could not load image: $e');
    }
  }

  void _showError(String msg) {
    setState(() { _errorMessage = msg; });
    HapticFeedback.heavyImpact();
  }

  void _toggleTorch() {
    _scanCtrl?.toggleTorch();
    setState(() => _torchOn = !_torchOn);
    HapticFeedback.lightImpact();
  }

  void _showAlreadyMarkedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Already Marked', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Your attendance has already been marked for this session.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () { Get.back(); Get.back(); },
            child: const Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Column(
              children: [
                _buildHeader(),
                _buildProgressBar(),
                Expanded(child: _buildScannerSection()),
                if (!_scanSuccess) _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
            onPressed: () => Get.back(),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan QR Code',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
                ),
                Text(
                  'Point at the session QR code',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
          // Torch toggle
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? AppTheme.warning : AppTheme.textHint,
              size: 22,
            ),
            onPressed: _toggleTorch,
          ),
          // Upload option
          IconButton(
            icon: const Icon(Icons.image_rounded, color: AppTheme.textHint, size: 22),
            onPressed: _uploadQrImage,
            tooltip: 'Upload QR Image',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Obx(() => BiometricProgressBar(
            // QR flow: BLE ✓ → QR Scan → Done  (no Liveness, no Face)
            flowMode: AttendanceFlowMode.qr,
            currentStep: _scanSuccess ? BiometricStep.done : BiometricStep.qr,
            bleVerified: _attendance.bleVerified.value,
            qrVerified: _scanSuccess,
          )),
    );
  }

  Widget _buildScannerSection() {
    return Stack(
      children: [
        // Camera — only show scanner if controller is ready
        if (_scanCtrl != null)
          MobileScanner(
            controller: _scanCtrl!,
            onDetect: _onDetect,
          )
        else
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),

        // Dark overlay with transparent center
        Positioned.fill(
          child: _QrDarkOverlay(),
        ),

        // QR frame overlay
        Center(
          child: QrScannerOverlay(
            isScanning: !_scanSuccess && !_scanError,
            isSuccess: _scanSuccess,
            isError: _scanError,
            size: MediaQuery.of(context).size.width * 0.72,
          ),
        ),

        // Instructions text
        if (!_scanSuccess && !_scanError)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppTheme.primary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Align QR code within the frame',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Success preview card
        if (_scanSuccess && _sessionPreview != null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ScaleTransition(
              scale: _successScale,
              child: _buildSessionPreviewCard(),
            ),
          ),

        // Error message
        if (_errorMessage != null && !_scanSuccess)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.errorCard(0.4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSessionPreviewCard() {
    final session = _sessionPreview!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.successCard(0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 22),
              SizedBox(width: 10),
              Text(
                'QR Verified!',
                style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.success, height: 1, thickness: 0.3),
          const SizedBox(height: 12),
          _infoRow(Icons.book_rounded, 'Subject', session['subject_name']?.toString() ?? '—'),
          const SizedBox(height: 8),
          _infoRow(Icons.meeting_room_rounded, 'Classroom', session['classroom_name']?.toString() ?? '—'),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 8, height: 8, child: CircularProgressIndicator(color: AppTheme.success, strokeWidth: 2)),
              SizedBox(width: 8),
              Text(
                'Marking attendance...',
                style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 14),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Obx(() => _attendance.isLoading.value
          ? const LinearProgressIndicator(color: AppTheme.primary)
          : OutlinedButton.icon(
              onPressed: _uploadQrImage,
              icon: const Icon(Icons.image_rounded, size: 18),
              label: const Text('Upload QR Image Instead'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.textHint.withValues(alpha: 0.4)),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )),
    );
  }
}

// ─── QR Dark Vignette Overlay ────────────────────────────────
class _QrDarkOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final frameSize = screenW * 0.72;
    final cx = screenW / 2;
    final cy = MediaQuery.of(context).size.height / 2;

    return CustomPaint(
      painter: _VignettePainter(centerX: cx, centerY: cy, frameSize: frameSize),
    );
  }
}

class _VignettePainter extends CustomPainter {
  final double centerX, centerY, frameSize;
  const _VignettePainter({required this.centerX, required this.centerY, required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final holeRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: frameSize,
      height: frameSize,
    );

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(holeRect, const Radius.circular(16)));

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VignettePainter old) => false;
}
