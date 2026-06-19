import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_attendance_system/widgets/stat_card.dart';

void main() {
  testWidgets('StatCard renders label, value, and subtitle', (WidgetTester tester) async {
    // Build StatCard in a testable environment
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Total Classes',
            value: '42',
            icon: Icons.class_,
            color: Colors.purple,
            subtitle: '85% Present',
          ),
        ),
      ),
    );

    // Verify that the label is displayed
    expect(find.text('Total Classes'), findsOneWidget);

    // Verify that the value is displayed
    expect(find.text('42'), findsOneWidget);

    // Verify that the subtitle is displayed
    expect(find.text('85% Present'), findsOneWidget);
  });

  testWidgets('AttendanceRing displays correct percentage text', (WidgetTester tester) async {
    // Build AttendanceRing in a testable environment
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttendanceRing(
            percentage: 78.5,
            size: 100,
          ),
        ),
      ),
    );

    // Verify that the percentage text is formatted and displayed
    expect(find.text('78.5%'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
  });
}
