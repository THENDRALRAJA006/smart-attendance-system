// ============================================================
// SmartAttend — Teacher Shell (v12 Premium Light)
// Floating bottom navigation: Home, Sessions, Reports,
// Timetable, Profile
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/erp_controller.dart';
import '../../controllers/faculty_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sa_bottom_nav.dart';
import 'teacher_dashboard_screen.dart';
import 'session_history_screen.dart';
import 'teacher_reports_screen.dart';
import 'teacher_timetable_screen.dart';
import '../auth/profile_screen.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<AuthController>()) {
      Get.put(AuthController(), permanent: true);
    }
    if (!Get.isRegistered<SessionController>()) {
      Get.put(SessionController(), permanent: true);
    }
    if (!Get.isRegistered<FacultyController>()) {
      Get.put(FacultyController(), permanent: true);
    }
    if (!Get.isRegistered<ErpController>()) {
      Get.put(ErpController(), permanent: true);
    }
    _pages = const [
      TeacherDashboardScreen(),
      SessionHistoryScreen(),
      TeacherReportsScreen(),
      TeacherTimetableScreen(),
      ProfileScreen(),
    ];
  }

  final List<SANavItem> _navItems = const [
    SANavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    SANavItem(
      icon: Icons.list_alt_outlined,
      activeIcon: Icons.list_alt_rounded,
      label: 'Sessions',
    ),
    SANavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Reports',
    ),
    SANavItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Timetable',
    ),
    SANavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      extendBody: true,
      bottomNavigationBar: SABottomNav(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
