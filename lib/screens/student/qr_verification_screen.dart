// ============================================================
// SmartAttend — QR Verification Screen (v3)
// Two methods: Live QR Scanner + Upload QR Image
// After QR is validated → navigate to Face Verification
//
// v3: alreadyMarked guard at screen entry,
//     duplicate-attendance dialog improvements,
//     tab state management fix,
//     post-upload session info preview
// ============================================================

import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../controllers/attendance_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';

// ─── Local QR Decoder (image bytes) ─────────────────────────
// Uses mobile_scanner's analyzeImage for offline decoding
class QrVerificationScreen extends StatefulWidget {
  const QrVerificationScreen({super.key});

  @override
  State<QrVerificationScreen> createState() => _QrVerificationScreenState();
}

class _QrVerificationScreenState extends State<QrVerificationScreen>
    with SingleTickerProviderStateMixin {
  final AttendanceController _attendance = Get.find<AttendanceController>();
  final MobileScannerController _scanCtrl = MobileScannerController();
  final ImagePicker _picker = ImagePicker();

  // ─── Tabs ─────────────────────────────────────────────────
  late TabController _tabController;

  // ─── State ────────────────────────────────────────────────
  bool _processing = false;
  String? _error;
  String? _uploadedImagePath;
  bool _scannerActive = true;

  // ─── Decoded session info (shown after upload) ────────────
  String? _decodedSubjectName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Check alreadyMarked at entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_attendance.alreadyMarked) {
        _showAlreadyMarkedDialog();
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (_tabController.index == 0 && !_scannerActive) {
      _scanCtrl.start();
      setState(() => _scannerActive = true);
    } else if (_tabController.index == 1 && _scannerActive) {
      _scanCtrl.stop();
      setState(() => _scannerActive = false);
    }
    setState(() {}); // Rebuild for torch icon
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _scanCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── Handle Scanned Barcode ──────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    await _processQrToken(barcode!.rawValue!);
  }

  // ─── Upload QR Image ─────────────────────────────────────
  Future<void> _uploadQrImage(ImageSource source) async {
    if (_processing) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (picked == null) return;

      setState(() {
        _processing = true;
        _error = null;
        _uploadedImagePath = picked.path;
        _decodedSubjectName = null;
      });

      dev.log('[QR_UPLOAD] Analyzing image: ${picked.path}');

      // Use MobileScanner's analyzeImage to decode QR from file
      final BarcodeCapture? result =
          await _scanCtrl.analyzeImage(picked.path);

      if (result == null || result.barcodes.isEmpty) {
        if (mounted) {
          setState(() {
            _processing = false;
            _error = 'No QR code found in the selected image. Please try a clearer photo.';
          });
        }
        return;
      }

      final rawValue = result.barcodes.first.rawValue;
      if (rawValue == null) {
        if (mounted) {
          setState(() {
            _processing = false;
            _error = 'QR code could not be read. Please try again.';
          });
        }
        return;
      }

      dev.log('[QR_UPLOAD] Decoded QR: $rawValue');
      await _processQrToken(rawValue);
    } catch (e) {
      dev.log('[QR_UPLOAD] Error: $e');
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'Failed to read image: ${e.toString()}';
        });
      }
    }
  }

  // ─── Process QR Token ────────────────────────────────────
  Future<void> _processQrToken(String qrToken) async {
    if (!_processing) {
      setState(() {
        _processing = true;
        _error = null;
      });
    }

    await _scanCtrl.stop();

    // Local decode check
    bool locallyValid = _isSmartAttendQr(qrToken);
    if (!locallyValid) {
      if (mounted) {
        setState(() {
          _error = 'Invalid QR code. Please scan a valid SmartAttend attendance QR.';
          _processing = false;
          _uploadedImagePath = null;
          _decodedSubjectName = null;
        });
      }
      if (_tabController.index == 0) await _scanCtrl.start();
      return;
    }

    // Validate with backend
    final success = await _attendance.validateQrToken(qrToken);

    if (!mounted) return;

    if (success) {
      // Show decoded info briefly then navigate
      setState(() {
        _decodedSubjectName = _attendance.deepLinkSessionSubject.value;
        _processing = false;
      });

      // Brief pause to show decoded session info
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // Navigate to face verification
      Get.offNamed(
        AppConstants.routeAttendanceVerification,
        arguments: {'from_qr': true},
      );
    } else {
      if (mounted) {
        setState(() {
          _error = _attendance.error.value.isNotEmpty
              ? _attendance.error.value
              : 'QR validation failed. Please try again.';
          _processing = false;
          _uploadedImagePath = null;
          _decodedSubjectName = null;
        });

        if (_attendance.result.value == AttendanceResult.alreadyMarked ||
            _attendance.hasDuplicateError.value) {
          _showAlreadyMarkedDialog();
          return;
        }

        if (_tabController.index == 0) await _scanCtrl.start();
      }
    }
  }

  // ─── Check if QR is SmartAttend format ───────────────────
  bool _isSmartAttendQr(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decodedStr = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(decodedStr) as Map<String, dynamic>;
      return payloadMap['type'] == 'qr_attendance' &&
          payloadMap['session_id'] != null;
    } catch (_) {
      return false;
    }
  }

  void _showAlreadyMarkedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 26),
            SizedBox(width: 10),
            Text('Already Marked',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: const Text(
          'You have already marked attendance for this session. No further action needed.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // close dialog
              Get.until((r) => r.settings.name == AppConstants.routeStudentDashboard);
            },
            child: const Text('Go to Dashboard',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload QR Image',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select the source for your QR code image',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _UploadOptionTile(
              id: 'gallery_option',
              icon: Icons.photo_library_rounded,
              color: AppTheme.primary,
              title: 'Gallery / Photos',
              subtitle: 'PNG, JPG, JPEG supported',
              onTap: () {
                Get.back();
                _uploadQrImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
            _UploadOptionTile(
              id: 'files_option',
              icon: Icons.folder_rounded,
              color: AppTheme.accent,
              title: 'Files',
              subtitle: 'Browse your device storage',
              onTap: () {
                Get.back();
                _uploadQrImage(ImageSource.gallery); // Files also uses gallery picker
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── App Bar ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textPrimary, size: 20),
                      onPressed: () => Get.back(),
                    ),
                    const Expanded(
                      child: Text(
                        'QR Verification',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Torch toggle (only on scanner tab)
                    if (_tabController.index == 0)
                      IconButton(
                        icon: const Icon(Icons.flash_on_rounded,
                            color: AppTheme.textSecondary, size: 22),
                        onPressed: () => _scanCtrl.toggleTorch(),
                      ),
                  ],
                ),
              ),

              // ─── Session Info banner (from active session) ─
              Obx(() {
                final subject = _attendance.activeSession.value?.subjectName
                    ?? _attendance.deepLinkSessionSubject.value;
                if (subject.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.book_rounded,
                            color: AppTheme.primary, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // ─── Tab Bar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.qr_code_scanner_rounded, size: 18),
                        text: 'Live Scanner',
                      ),
                      Tab(
                        icon: Icon(Icons.upload_rounded, size: 18),
                        text: 'Upload Image',
                      ),
                    ],
                    onTap: (index) {
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Tab Content ──────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildLiveScannerTab(),
                    _buildUploadTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Live Scanner Tab ────────────────────────────────────
  Widget _buildLiveScannerTab() {
    return Stack(
      children: [
        Column(
          children: [
            // Camera view
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanCtrl,
                        onDetect: _onDetect,
                      ),
                      // QR frame overlay
                      CustomPaint(
                        painter: _QrFramePainter(),
                      ),
                      // Processing overlay
                      if (_processing)
                        Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                    color: AppTheme.primary),
                                SizedBox(height: 16),
                                Text(
                                  'Validating QR...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instruction
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Point your camera at the QR code displayed by your faculty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Error
            if (_error != null && !_processing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ErrorBanner(message: _error!),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ],
    );
  }

  // ─── Upload Tab ──────────────────────────────────────────
  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Upload Area
          GestureDetector(
            onTap: _processing ? null : _showUploadOptions,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 220,
              decoration: BoxDecoration(
                color: _uploadedImagePath != null
                    ? Colors.transparent
                    : AppTheme.bgCard.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _uploadedImagePath != null
                      ? AppTheme.success.withValues(alpha: 0.4)
                      : AppTheme.primary.withValues(alpha: 0.3),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: _uploadedImagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(_uploadedImagePath!),
                            fit: BoxFit.cover,
                          ),
                          if (_processing)
                            Container(
                              color: Colors.black.withValues(alpha: 0.6),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                        color: AppTheme.primary),
                                    SizedBox(height: 12),
                                    Text(
                                      'Reading QR code...',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Decoded success overlay
                          if (!_processing && _decodedSubjectName != null)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.9),
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(18)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'QR Decoded: $_decodedSubjectName',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.upload_rounded,
                              color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap to Upload QR Image',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'PNG • JPG • JPEG',
                          style: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Error
          if (_error != null && !_processing)
            _ErrorBanner(message: _error!),

          const SizedBox(height: 20),

          // Upload Button
          GradientButton(
            id: 'upload_qr_button',
            text: _uploadedImagePath != null
                ? 'Choose Different Image'
                : 'Upload QR Image',
            icon: Icons.upload_file_rounded,
            isLoading: _processing,
            onPressed: _processing ? null : _showUploadOptions,
          ),

          const SizedBox(height: 12),

          // Instructions Card
          GlassmorphismCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: AppTheme.accent, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'How to use QR upload',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...[
                  '📸 Screenshot the QR shown by your faculty',
                  '📁 Upload it from your gallery or files',
                  '🔍 The app will automatically detect and decode it',
                  '🧑‍💻 After QR is validated, complete face verification',
                  '✅ Attendance will be marked after face match',
                ].map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        tip,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upload Option Tile ───────────────────────────────────────
class _UploadOptionTile extends StatelessWidget {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _UploadOptionTile({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(id),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.5), size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── QR Frame Painter ─────────────────────────────────────────
class _QrFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerSize = 28.0;
    const frameSize = 230.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final l = cx - frameSize / 2;
    final t = cy - frameSize / 2;
    final r = cx + frameSize / 2;
    final b = cy + frameSize / 2;

    // Dim overlay
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromLTRBR(l, t, r, b, const Radius.circular(16))),
      ),
      dimPaint,
    );

    final p = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // TL
    canvas.drawLine(Offset(l, t + cornerSize), Offset(l, t), p);
    canvas.drawLine(Offset(l, t), Offset(l + cornerSize, t), p);
    // TR
    canvas.drawLine(Offset(r - cornerSize, t), Offset(r, t), p);
    canvas.drawLine(Offset(r, t), Offset(r, t + cornerSize), p);
    // BL
    canvas.drawLine(Offset(l, b - cornerSize), Offset(l, b), p);
    canvas.drawLine(Offset(l, b), Offset(l + cornerSize, b), p);
    // BR
    canvas.drawLine(Offset(r - cornerSize, b), Offset(r, b), p);
    canvas.drawLine(Offset(r, b - cornerSize), Offset(r, b), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
