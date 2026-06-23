// ============================================================
// SmartAttend — Profile Screen
// Shows user info, attendance %, face registration status
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ─── App Bar ─────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
                  onPressed: () => Get.back(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProfileHeader(auth: auth),
                ),
              ),

              // ─── Content ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoSection(auth: auth),
                      const SizedBox(height: 20),
                      if (auth.role.value == 'student') ...[
                        _AttendanceStats(),
                        const SizedBox(height: 20),
                      ],
                      _AccountActions(auth: auth),
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

// ─── Header ────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final AuthController auth;
  const _ProfileHeader({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C5CFF), Color(0xFF5A3FCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        child: Obx(() {
          final student = auth.currentStudent.value;
          final faculty = auth.currentFaculty.value;
          final name = student?.name ?? faculty?.name ?? 'User';
          final role = auth.role.value;
          final email = student?.email ?? faculty?.email ?? '';
          final hasFace = student?.hasFaceRegistered == true;

          return Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: student?.faceImageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              student!.faceImageUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  if (role == 'student')
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: hasFace ? AppTheme.success : AppTheme.warning,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          hasFace ? Icons.face : Icons.face_retouching_off,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Info Section ─────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  final AuthController auth;
  const _InfoSection({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final student = auth.currentStudent.value;
      final faculty = auth.currentFaculty.value;

      final items = <_InfoItem>[];

      if (student != null) {
        items.addAll([
          _InfoItem('Registration No.', student.regNo, Icons.badge_outlined),
          _InfoItem('Department', student.department, Icons.school_outlined),
          _InfoItem('Year / Section', '${student.year} / ${student.section}', Icons.calendar_today_outlined),
          _InfoItem(
            'Face Status',
            student.hasFaceRegistered ? 'Registered ✓' : 'Not Registered',
            Icons.face_outlined,
            valueColor: student.hasFaceRegistered ? AppTheme.success : AppTheme.warning,
          ),
        ]);
      } else if (faculty != null) {
        items.addAll([
          _InfoItem('Department', faculty.department ?? 'N/A', Icons.school_outlined),
          _InfoItem('Subjects', '${faculty.subjects.length} assigned', Icons.book_outlined),
        ]);
      }

      return Container(
        decoration: AppTheme.glassmorphismCard,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account Information',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 16),
            ...items.map((item) => _buildInfoRow(item)),
          ],
        ),
      );
    });
  }

  Widget _buildInfoRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(item.label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(item.value,
              style: TextStyle(
                color: item.valueColor ?? AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _InfoItem(this.label, this.value, this.icon, {this.valueColor});
}

// ─── Attendance Stats (student only) ─────────────────────
class _AttendanceStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final student = AuthController.to.currentStudent.value;
    if (student == null) return const SizedBox.shrink();

    return Container(
      decoration: AppTheme.glassmorphismCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance Overview',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCircle(
                value: student.attendancePercentage ?? 0.0,
                label: 'Overall',
                color: AppTheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow('Total Classes', '${student.totalClasses ?? 0}'),
                    const SizedBox(height: 8),
                    _StatRow('Attended', '${student.attendedClasses ?? 0}',
                        valueColor: AppTheme.success),
                    const SizedBox(height: 8),
                    _StatRow(
                      'Missed',
                      '${(student.totalClasses ?? 0) - (student.attendedClasses ?? 0)}',
                      valueColor: AppTheme.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradientButton(
            text: 'View Full Report',
            icon: Icons.bar_chart,
            onPressed: () => Get.toNamed(AppConstants.routeReports),
          ),
        ],
      ),
    );
  }
}

class _StatCircle extends StatelessWidget {
  final double value;
  final String label;
  final Color color;
  const _StatCircle({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 8,
              backgroundColor: AppTheme.bgCardLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            )),
      ],
    );
  }
}

// ─── Account Actions ──────────────────────────────────────
class _AccountActions extends StatelessWidget {
  final AuthController auth;
  const _AccountActions({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isStudent = auth.role.value == 'student';
    return Container(
      decoration: AppTheme.glassmorphismCard,
      child: Column(
        children: [
          if (isStudent) ...[
            _ActionTile(
              icon: Icons.face,
              label: 'Update Face Registration',
              onTap: () => Get.toNamed(AppConstants.routeFaceRegister),
            ),
            const Divider(height: 1, color: Color(0x22FFFFFF)),
            _ActionTile(
              icon: Icons.history,
              label: 'Attendance History',
              onTap: () => Get.toNamed(AppConstants.routeAttendanceHistory),
            ),
            const Divider(height: 1, color: Color(0x22FFFFFF)),
            _ActionTile(
              icon: Icons.bar_chart,
              label: 'Reports & Analytics',
              onTap: () => Get.toNamed(AppConstants.routeReports),
            ),
            const Divider(height: 1, color: Color(0x22FFFFFF)),
          ],
          _ActionTile(
            icon: Icons.logout,
            label: 'Sign Out',
            color: AppTheme.error,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              auth.logout();
            },
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
