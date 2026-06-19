// ============================================================
// Attendance Badge Widget
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AttendanceBadge extends StatelessWidget {
  final String status;
  const AttendanceBadge({super.key, required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'late':
        return AppTheme.warning;
      default:
        return AppTheme.textHint;
    }
  }

  IconData get _icon {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.access_time_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 14),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
