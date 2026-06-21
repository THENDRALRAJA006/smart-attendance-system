// ============================================================
// SmartAttend — QR Generator Screen (Faculty)
// Faculty generates a session QR code for student scanning
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controllers/faculty_controller.dart';
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
                                      color: AppTheme.textSecondary, fontSize: 13),
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
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  hint: const Text('Choose session',
                                      style: TextStyle(color: AppTheme.textHint)),
                                  items: sessions.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s['id'] as int,
                                      child: Text(
                                        '${s['subject_name']} — ${s['classroom_name']}',
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary, fontSize: 13),
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
                                  color: AppTheme.primary.withValues(alpha: 0.4),
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
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (_, __) {
                            final remaining = _timeRemaining();
                            final expired = remaining == 'Expired';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: (expired ? AppTheme.error : AppTheme.success)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (expired ? AppTheme.error : AppTheme.success)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    expired ? Icons.timer_off : Icons.timer,
                                    color: expired ? AppTheme.error : AppTheme.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    remaining,
                                    style: TextStyle(
                                      color: expired ? AppTheme.error : AppTheme.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
                                color: AppTheme.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppTheme.error, fontSize: 13)),
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
