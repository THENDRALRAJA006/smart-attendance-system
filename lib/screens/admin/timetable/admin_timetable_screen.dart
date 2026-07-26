// ============================================================
// SmartAttend — Admin Timetable Screen (v13 ERP Timetable)
// Redirects to Academic Management Screen
// ============================================================

import 'package:flutter/material.dart';

import '../academic/academic_management_screen.dart';

class AdminTimetableScreen extends StatelessWidget {
  const AdminTimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AcademicManagementScreen();
  }
}
