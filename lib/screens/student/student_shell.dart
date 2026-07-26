// ============================================================
// SmartAttend — Student Shell (v12 Premium Light)
// Floating bottom navigation: Home, Attendance, Reports,
// Timetable, Profile
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/erp_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/sa_bottom_nav.dart';
import 'student_dashboard.dart';
import 'attendance_history_screen.dart';
import 'reports_screen.dart';
import 'student_timetable_screen.dart';
import '../auth/profile_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ErpController>()) {
      Get.put(ErpController(), permanent: true);
    }
    _pages = const [
      StudentDashboard(),
      AttendanceHistoryScreen(),
      ReportsScreen(),
      StudentTimetableScreen(),
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
      icon: Icons.how_to_reg_outlined,
      activeIcon: Icons.how_to_reg_rounded,
      label: 'Attendance',
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
