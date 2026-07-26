// ============================================================
// SmartAttend — Admin Shell (v12 Premium Light)
// Floating bottom navigation bar with 5 main sections,
// replacing the old NavigationRail/Drawer design.
// All page content and controllers preserved.
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sa_bottom_nav.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'students/students_screen.dart';
import 'staff/staff_screen.dart';
import 'classes/classes_screen.dart';
import 'attendance/attendance_management_screen.dart';
import 'faces/face_management_screen.dart';
import 'devices/device_security_screen.dart';
import 'ble/ble_management_screen.dart';
import 'reports/admin_reports_screen.dart';
import 'settings/settings_screen.dart';
import 'audit/audit_logs_screen.dart';
import 'academic/academic_management_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  // Bottom nav sections (5 tabs)
  final List<SANavItem> _navItems = const [
    SANavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    SANavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'People',
    ),
    SANavItem(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      label: 'Attendance',
    ),
    SANavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Reports',
    ),
    SANavItem(
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.more_horiz_rounded,
      label: 'More',
    ),
  ];

  // Main page for each tab
  static const List<Widget> _mainPages = [
    AdminDashboardScreen(),
    StudentsScreen(),
    AttendanceManagementScreen(),
    AdminReportsScreen(),
    _MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: _AdminAppBar(selectedIndex: _selectedIndex),
      body: IndexedStack(
        index: _selectedIndex,
        children: _mainPages,
      ),
      extendBody: true,
      bottomNavigationBar: SABottomNav(
        currentIndex: _selectedIndex,
        items: _navItems,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ─── Custom AppBar ────────────────────────────────────────
class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  const _AdminAppBar({required this.selectedIndex});

  static const _titles = [
    'Dashboard',
    'People',
    'Attendance',
    'Reports & Analytics',
    'More',
  ];

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_titles[selectedIndex],
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('Welcome, Admin',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          // Notification icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppTheme.textPrimary, size: 22),
            onPressed: () {},
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => _showAdminMenu(context, auth),
            child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('A',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
          ),
        ]),
      ),
    );
  }

  void _showAdminMenu(BuildContext context, AuthController auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
            title: Text('Sign Out',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: AppTheme.error)),
            onTap: () { Get.back(); auth.logout(); },
          ),
        ]),
      ),
    );
  }
}

// ─── "More" page — links to all other admin sections ──────
class _MorePage extends StatelessWidget {
  const _MorePage();

  @override
  Widget build(BuildContext context) {
    final sections = [
      {'label': 'Staff Management', 'icon': Icons.badge_rounded,
        'color': AppTheme.secondary, 'page': () => const StaffScreen()},
      {'label': 'Classes & Subjects', 'icon': Icons.account_tree_rounded,
        'color': AppTheme.accent, 'page': () => const ClassesScreen()},
      {'label': 'Face Recognition', 'icon': Icons.face_rounded,
        'color': AppTheme.primary, 'page': () => const FaceManagementScreen()},
      {'label': 'BLE Devices', 'icon': Icons.bluetooth_rounded,
        'color': const Color(0xFF3B82F6), 'page': () => const BleManagementScreen()},
      {'label': 'Device Security', 'icon': Icons.security_rounded,
        'color': AppTheme.warning, 'page': () => const DeviceSecurityScreen()},
      {'label': 'Academic Management', 'icon': Icons.school_rounded,
        'color': AppTheme.accentTeal, 'page': () => const AcademicManagementScreen()},
      {'label': 'Settings', 'icon': Icons.settings_rounded,
        'color': AppTheme.textSecondary, 'page': () => const SettingsScreen()},
      {'label': 'Audit Logs', 'icon': Icons.history_rounded,
        'color': AppTheme.error, 'page': () => const AuditLogsScreen()},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Text('Management',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppTheme.textHint, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...sections.map((s) {
          final color = s['color'] as Color;
          final pageBuilder = s['page'] as Widget Function();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.subtleShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Get.to(pageBuilder, transition: Transition.rightToLeft),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s['icon'] as IconData, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(s['label'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary))),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textHint, size: 18),
                  ]),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

