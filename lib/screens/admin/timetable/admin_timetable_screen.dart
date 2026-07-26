// ============================================================
// SmartAttend — Admin Timetable Screen (v13 ERP Timetable)
// Redirects to Academic Management & Timetable Spreadsheet Editor
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../academic/academic_management_screen.dart';
import '../academic/timetable_editor_screen.dart';

class AdminTimetableScreen extends StatelessWidget {
  const AdminTimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AcademicManagementScreen();
  }
}
