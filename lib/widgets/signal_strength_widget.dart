// ============================================================
// Signal Strength Widget — BLE RSSI Indicator
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SignalStrengthWidget extends StatefulWidget {
  final int rssi;
  final String label;
  final bool isInRange;

  const SignalStrengthWidget({
    super.key,
    required this.rssi,
    required this.label,
    required this.isInRange,
  });

  @override
  State<SignalStrengthWidget> createState() => _SignalStrengthWidgetState();
}

class _SignalStrengthWidgetState extends State<SignalStrengthWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int get _bars {
    if (widget.rssi >= -50) return 4;
    if (widget.rssi >= -60) return 3;
    if (widget.rssi >= -70) return 2;
    if (widget.rssi >= -80) return 1;
    return 0;
  }

  Color get _signalColor {
    if (!widget.isInRange) return AppTheme.error;
    if (widget.rssi >= -60) return AppTheme.success;
    if (widget.rssi >= -70) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Signal Bars ────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isInRange ? _pulseAnimation.value : 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (index) {
                  final barHeight = 12.0 + (index * 8.0);
                  final isActive = index < _bars;
                  return Container(
                    width: 10,
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isActive
                          ? _signalColor
                          : AppTheme.textHint.withValues(alpha: 0.3),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: _signalColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // ─── RSSI Value ─────────────────────────────────────
        Text(
          '${widget.rssi} dBm',
          style: TextStyle(
            color: _signalColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        // ─── Label ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _signalColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _signalColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _signalColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Compact signal icon ─────────────────────────────────────
class SignalIcon extends StatelessWidget {
  final int rssi;
  const SignalIcon({super.key, required this.rssi});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    if (rssi >= -60) {
      color = AppTheme.success;
      icon = Icons.signal_wifi_4_bar;
    } else if (rssi >= -70) {
      color = AppTheme.warning;
      icon = Icons.network_wifi_2_bar;
    } else {
      color = AppTheme.error;
      icon = Icons.signal_wifi_off;
    }
    return Icon(icon, color: color, size: 18);
  }
}
