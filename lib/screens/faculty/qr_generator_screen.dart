// ============================================================
// SmartAttend — QR Generator Screen (Faculty) v2
// + Download QR as PNG
// + Fullscreen / Board Mode for projector display
// + Share QR via system share sheet
// ============================================================

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../controllers/faculty_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen>
    with TickerProviderStateMixin {
  final FacultyController _ctrl = Get.find<FacultyController>();

  String? _qrToken;
  DateTime? _expiresAt;
  bool _loading = false;
  bool _downloadingPng = false;
  String? _error;
  int _selectedSessionId = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _timerCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 10),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timerCtrl.dispose();
    super.dispose();
  }

  // ─── Generate QR Token ──────────────────────────────────
  Future<void> _generateQr() async {
    if (_selectedSessionId == 0) {
      Get.snackbar('Select Session', 'Please select an active session first.',
          backgroundColor: AppTheme.warning.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _ctrl.generateQrToken(_selectedSessionId);
      if (result != null) {
        setState(() {
          _qrToken = result['token'];
          _expiresAt = DateTime.tryParse(result['expires_at'] ?? '');
        });
        _timerCtrl.forward(from: 0);
      } else {
        setState(() => _error = 'Failed to generate QR code');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Download QR PNG ────────────────────────────────────
  Future<void> _downloadQrPng() async {
    if (_selectedSessionId == 0) return;

    setState(() {
      _downloadingPng = true;
      _error = null;
    });

    try {
      final response = await ApiClient.to.get<List<int>>(
        '${AppConstants.endpointDownloadQr}/$_selectedSessionId',
        options: dio.Options(
          responseType: dio.ResponseType.bytes,
        ),
      );

      final bytes = response.data;
      if (bytes == null) {
        throw Exception('Empty response data received');
      }

      // Save to temp directory then share/save
      final dir = await getTemporaryDirectory();
      final filename =
          response.headers.value('content-disposition')
              ?.split('filename=')
              .last
              .replaceAll('"', '') ??
          'SmartAttend_QR_$_selectedSessionId.png';

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      Get.snackbar(
        '✅ QR Ready',
        'Opening share sheet...',
        backgroundColor: AppTheme.success.withValues(alpha: 0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'SmartAttend QR Code — Session $_selectedSessionId',
          text: 'Scan to mark attendance. Valid for 10 minutes.',
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Download failed: $e');
      }
    } finally {
      if (mounted) setState(() => _downloadingPng = false);
    }
  }

  // ─── Open Fullscreen Board Mode ─────────────────────────
  void _openFullscreen() {
    if (_qrToken == null) return;
    Get.to(
      () => _FullscreenQrScreen(
        qrToken: _qrToken!,
        expiresAt: _expiresAt,
        sessionId: _selectedSessionId,
      ),
      transition: Transition.fadeIn,
    );
  }

  // ─── Timer Display ──────────────────────────────────────
  String _timeRemaining() {
    if (_expiresAt == null) return '';
    final diff = _expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}m ${s}s remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: AppTheme.textPrimary),
                      onPressed: () => Get.back(),
                    ),
                    const Text('QR Attendance',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        )),
                    const Spacer(),
                    // Fullscreen button (only when QR is generated)
                    if (_qrToken != null)
                      IconButton(
                        tooltip: 'Fullscreen Board Mode',
                        icon: const Icon(Icons.fullscreen_rounded,
                            color: AppTheme.textSecondary, size: 26),
                        onPressed: _openFullscreen,
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ─── Session Picker ───────────────────
                      Obx(() {
                        final sessions = _ctrl.activeSessions;
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.glassmorphismCard,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Select Active Session',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  )),
                              const SizedBox(height: 12),
                              if (sessions.isEmpty)
                                const Text(
                                  'No active sessions. Start a session first.',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13),
                                )
                              else
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedSessionId == 0
                                      ? null
                                      : _selectedSessionId,
                                  dropdownColor: AppTheme.bgCard,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppTheme.bgCardLight,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                  ),
                                  hint: const Text('Choose session',
                                      style: TextStyle(
                                          color: AppTheme.textHint)),
                                  items: sessions.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s['id'] as int,
                                      child: Text(
                                        '${s['subject_name']} — ${s['classroom_name']}',
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedSessionId = v;
                                        _qrToken = null;
                                      });
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // ─── Generate Button ──────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.qr_code_2),
                          label: Text(_loading
                              ? 'Generating...'
                              : _qrToken == null
                                  ? 'Generate QR Code'
                                  : 'Refresh QR Code'),
                          onPressed: _loading ? null : _generateQr,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ─── QR Display ───────────────────────
                      if (_qrToken != null) ...[
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, child) => Transform.scale(
                            scale: _pulseAnim.value,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _qrToken!,
                              version: QrVersions.auto,
                              size: 220,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Timer
                        StreamBuilder(
                          stream:
                              Stream.periodic(const Duration(seconds: 1)),
                          builder: (_, __) {
                            final remaining = _timeRemaining();
                            final expired = remaining == 'Expired';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: (expired
                                            ? AppTheme.error
                                            : AppTheme.success)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (expired
                                              ? AppTheme.error
                                              : AppTheme.success)
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    expired
                                        ? Icons.timer_off
                                        : Icons.timer,
                                    color: expired
                                        ? AppTheme.error
                                        : AppTheme.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    remaining,
                                    style: TextStyle(
                                      color: expired
                                          ? AppTheme.error
                                          : AppTheme.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // ─── Action Buttons Row ──────────────
                        Row(
                          children: [
                            // Share / Download
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.share_rounded,
                                label: _downloadingPng
                                    ? 'Preparing...'
                                    : 'Share QR',
                                color: AppTheme.primary,
                                isLoading: _downloadingPng,
                                onTap: _downloadingPng
                                    ? null
                                    : _downloadQrPng,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Fullscreen / Board Mode
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.fullscreen_rounded,
                                label: 'Board Mode',
                                color: AppTheme.accent,
                                onTap: _openFullscreen,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Show this QR to students.\nValid for 10 minutes only.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],

                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppTheme.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppTheme.error,
                                        fontSize: 13)),
                              ),
                            ],
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
    );
  }
}

// ─── Reusable Action Button ───────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fullscreen Board Mode ────────────────────────────────────
class _FullscreenQrScreen extends StatelessWidget {
  final String qrToken;
  final DateTime? expiresAt;
  final int sessionId;

  const _FullscreenQrScreen({
    required this.qrToken,
    required this.expiresAt,
    required this.sessionId,
  });

  String _timeRemaining() {
    if (expiresAt == null) return '';
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 'EXPIRED';
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SmartAttend branding
              const Text(
                'SmartAttend',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan to Mark Attendance',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Large QR
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrToken,
                  version: QrVersions.auto,
                  size: MediaQuery.of(context).size.width * 0.6,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
              const SizedBox(height: 36),

              // Live countdown
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (_, __) {
                  final remaining = _timeRemaining();
                  final expired = remaining == 'EXPIRED';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      color: (expired ? Colors.red : AppTheme.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color:
                              (expired ? Colors.red : AppTheme.primary)
                                  .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          expired ? Icons.timer_off : Icons.timer_rounded,
                          color: expired
                              ? Colors.redAccent
                              : AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          expired ? 'QR EXPIRED' : 'Expires in $remaining',
                          style: TextStyle(
                            color: expired
                                ? Colors.redAccent
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              const Text(
                'Tap anywhere to exit',
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
