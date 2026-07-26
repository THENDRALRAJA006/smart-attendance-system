// ============================================================
// SmartAttend — Faculty Dashboard (Redirects to TeacherShell)
// ============================================================

import 'package:flutter/material.dart';
import 'teacher_shell.dart';

class FacultyDashboard extends StatelessWidget {
  const FacultyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherShell();
  }
}
