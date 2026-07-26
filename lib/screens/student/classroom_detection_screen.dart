// ============================================================
// SmartAttend — Classroom Detection Screen (Enterprise v2)
// BLE Scanner with premium radar animation, averaged RSSI,
// auto-select, haptic feedback, live signal bars
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/attendance_controller.dart';
import '../../core/services/ble_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/ble_radar_widget.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';

class ClassroomDetectionScreen extends StatefulWidget {
  const ClassroomDetectionScreen({super.key});

  @override
  State<ClassroomDetectionScreen> createState() => _ClassroomDetectionScreenState();
}

class _ClassroomDetectionScreenState extends State<ClassroomDetectionScreen>
    with TickerProviderStateMixin {
  final BleService _ble = Get.find();
  final AttendanceController _attendance = Get.find();

  late AnimationController _headerController;
  late Animation<double> _headerFade;

  Timer? _autoSelectTimer;
  String? _autoSelectDeviceId;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerController.forward();
    _startScan();
  }

  void _startScan() {
    _autoSelectTimer?.cancel();
    _autoSelectDeviceId = null;
    _attendance.startBLEScan();
  }

  void _rescan() {
    _ble.stopScan();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _ble.startScan(autoReconnect: true).catchError((_) {});
      }
    });
  }

  void _tryAutoSelect() {
    final classrooms = _ble.detectedClassrooms;
    final inRange = classrooms.where((c) => c.isInRange).toList();

    if (inRange.length == 1 && _autoSelectDeviceId == null && !_attendance.isLoading.value) {
      final classroom = inRange.first;
      _autoSelectDeviceId = classroom.deviceId;

      // Auto-select after 2 seconds of stable detection
      _autoSelectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _autoSelectDeviceId == classroom.deviceId) {
          HapticFeedback.mediumImpact();
          _attendance.selectClassroom(classroom);
        }
      });
    } else if (inRange.length != 1) {
      _autoSelectTimer?.cancel();
      _autoSelectDeviceId = null;
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _autoSelectTimer?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _headerFade,
            child: Column(
              children: [
                _buildHeader(),
                _buildSessionBanner(),
                const SizedBox(height: 16),
                _buildRadarSection(),
                const SizedBox(height: 16),
                _buildScanStatus(),
                const SizedBox(height: 12),
                Expanded(child: _buildClassroomList()),
                _buildRescanButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 24, 0),
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
                  'Classroom Detection',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Scanning via Bluetooth Low Energy',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: AppTheme.statusBadge(AppTheme.primary),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bluetooth, color: AppTheme.primary, size: 12),
                SizedBox(width: 4),
                Text(
                  'BLE',
                  style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBanner() {
    return Obx(() {
      final session = _attendance.activeSession.value;
      if (session == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppTheme.successCard(0.3),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.subtleGlow(AppTheme.success),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subjectName,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      'Active in ${session.classroomName}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: AppTheme.liveBadge,
                child: const Text(
                  '● LIVE',
                  style: TextStyle(color: AppTheme.success, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRadarSection() {
    return Obx(() {
      _tryAutoSelect();
      return BleRadarWidget(
        isScanning: _ble.isScanning.value,
        deviceCount: _ble.detectedClassrooms.length,
        hasInRangeDevice: _ble.detectedClassrooms.any((c) => c.isInRange),
        devices: _ble.detectedClassrooms.toList(),
      );
    });
  }

  Widget _buildScanStatus() {
    return Obx(() {
      final status  = _ble.bleStatus.value;
      final message = _ble.statusMessage.value;
      final count   = _ble.detectedClassrooms.length;
      final inRange = _ble.detectedClassrooms.where((c) => c.isInRange).length;

      String label;
      Color  labelColor;
      IconData? icon;

      switch (status) {
        case BleStatus.bluetoothOff:
          label = 'Bluetooth is off — please enable it';
          labelColor = AppTheme.error;
          icon = Icons.bluetooth_disabled_rounded;
          break;
        case BleStatus.permissionDenied:
          label = 'Bluetooth permission denied';
          labelColor = AppTheme.error;
          icon = Icons.lock_outline_rounded;
          break;
        case BleStatus.reconnecting:
          label = 'Reconnecting...';
          labelColor = AppTheme.warning;
          icon = Icons.refresh_rounded;
          break;
        case BleStatus.scanning:
          if (message.isNotEmpty) {
            label = message;
            labelColor = inRange > 0 ? AppTheme.success : AppTheme.primary;
          } else {
            label = 'Scanning for SmartAttend beacons...';
            labelColor = AppTheme.primary;
          }
          icon = null;
          break;
        default:
          label = count == 0
              ? 'No beacons found — tap Rescan'
              : '$count beacon(s) detected • $inRange in range';
          labelColor = count == 0
              ? AppTheme.textHint
              : inRange > 0 ? AppTheme.success : AppTheme.warning;
          icon = null;
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Row(
          key: ValueKey(label),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: labelColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildClassroomList() {
    return Obx(() {
      if (_ble.detectedClassrooms.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassmorphismCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bluetooth_disabled, color: AppTheme.textHint, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'No SmartAttend Beacons Detected',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Make sure you are inside the classroom with Bluetooth enabled. '
                    'The beacon must broadcast "SMART_ATTEND" in its name.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textHint, fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _ble.detectedClassrooms.length,
        itemBuilder: (context, index) {
          final classroom = _ble.detectedClassrooms[index];
          return _ClassroomCard(
            classroom: classroom,
            onTap: _attendance.isLoading.value
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _attendance.selectClassroom(classroom);
                  },
            isLoading: _attendance.isLoading.value,
          );
        },
      );
    });
  }

  Widget _buildRescanButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Obx(() {
        final scanning = _ble.isScanning.value;
        final isOff = _ble.bleStatus.value == BleStatus.bluetoothOff;
        return GradientButton(
          text: scanning
              ? 'Scanning...'
              : isOff
                  ? 'Enable Bluetooth'
                  : 'Rescan for Beacons',
          icon: scanning ? null : isOff ? Icons.bluetooth_rounded : Icons.refresh_rounded,
          isLoading: scanning,
          onPressed: scanning ? null : _rescan,
        );
      }),
    );
  }
}

// ─── Classroom Card ───────────────────────────────────────────
class _ClassroomCard extends StatelessWidget {
  final DetectedClassroom classroom;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ClassroomCard({required this.classroom, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isInRange = classroom.isInRange;
    final statusColor = isInRange ? AppTheme.success : AppTheme.error;
    final rssiStrength = _rssiStrength(classroom.rssi);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isInRange ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isInRange
                  ? AppTheme.success.withValues(alpha: 0.35)
                  : AppTheme.error.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: isInRange ? AppTheme.subtleGlow(AppTheme.success) : [],
          ),
          child: Row(
            children: [
              // ── Room icon ──────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1),
                ),
                child: Icon(Icons.meeting_room_rounded, color: statusColor, size: 26),
              ),
              const SizedBox(width: 14),

              // ── Details ────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.name.replaceAll('_', ' ').replaceAll('SMART ATTEND ', ''),
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // RSSI bars
                        ...List.generate(4, (i) => Container(
                          margin: const EdgeInsets.only(right: 2),
                          width: 4,
                          height: 8.0 + i * 3,
                          decoration: BoxDecoration(
                            color: i < rssiStrength
                                ? statusColor
                                : AppTheme.textHint.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )),
                        const SizedBox(width: 8),
                        Text(
                          '${classroom.rssi} dBm',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${classroom.signalLabel}',
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (classroom.sampleCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Avg of ${classroom.sampleCount} readings',
                          style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Status badge / Loading ─────────────────
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: AppTheme.statusBadge(statusColor),
                    child: Text(
                      isInRange ? 'In Range' : 'Out',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                  if (isInRange) ...[
                    const SizedBox(height: 8),
                    isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primary, size: 14),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _rssiStrength(int rssi) {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -72) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}
