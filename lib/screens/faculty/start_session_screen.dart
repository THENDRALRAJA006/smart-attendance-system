// ============================================================
// SmartAttend — Start Session Screen (v11)
// Semantic BLE range (Small/Medium/Large/Lab/Custom),
// BLE Required, Face Verification, Auto End toggles.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/erp_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class _RangePreset {
  final String label;
  final String sublabel;
  final IconData icon;
  final int metres;
  const _RangePreset(this.label, this.sublabel, this.icon, this.metres);
}

const List<_RangePreset> _rangePresets = [
  _RangePreset('Small Classroom',  '5 m · Office / Tutorial Room', Icons.meeting_room_outlined,  5),
  _RangePreset('Medium Classroom', '10 m · Standard Classroom',    Icons.menu_book_outlined,      10),
  _RangePreset('Large Classroom',  '15 m · Lecture Hall',          Icons.school_outlined,         15),
  _RangePreset('Laboratory',       '20 m · Lab / Workshop',        Icons.science_outlined,        20),
];

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});
  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  final SessionController _sc   = Get.find();
  final AuthController    _auth = Get.find();
  final _deptCtrl         = TextEditingController();
  final _sectionCtrl      = TextEditingController();
  final _customRadiusCtrl = TextEditingController();

  int  _rangeIndex      = 3;
  bool _useCustomRadius = false;

  static const _durationOptions = [2, 5, 10, 15];
  static const _yearOptions     = [1, 2, 3, 4];
  bool get _isAdmin => _auth.role.value == 'admin';

  @override
  void initState() {
    super.initState();
    _sc.resetForm();
    _deptCtrl.addListener(() => _sc.selectedDepartment.value = _deptCtrl.text);
    _sectionCtrl.addListener(() => _sc.selectedSection.value = _sectionCtrl.text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAutoFill());
  }

  void _applyAutoFill() async {
    final args = Get.arguments as Map<String, dynamic>?;
    Map<String, dynamic>? af = args?['auto_fill'] as Map<String, dynamic>?;

    if (af == null && Get.isRegistered<ErpController>()) {
      final fill = await ErpController.to.fetchCurrentPeriod();
      if (fill != null && fill.found) {
        af = {
          'department': fill.department,
          'year': fill.year,
          'section': fill.section,
          'subject_id': fill.subjectId,
          'classroom_id': fill.classroomId,
        };
      }
    }

    if (af == null) return;
    if (af['department']  != null) { _deptCtrl.text = af['department'].toString(); _sc.selectedDepartment.value = _deptCtrl.text; }
    if (af['section']     != null) { _sectionCtrl.text = af['section'].toString(); _sc.selectedSection.value = _sectionCtrl.text; }
    if (af['year']        != null) { final yr = int.tryParse(af['year'].toString()); if (yr != null && AppConstants.yearOptions.contains(yr)) _sc.selectedYear.value = yr; }
    if (af['subject_id']  != null) { final sid = int.tryParse(af['subject_id'].toString()); if (sid != null) _sc.selectedSubjectId.value = sid; }
    if (af['classroom_id']!= null) { final cid = int.tryParse(af['classroom_id'].toString()); if (cid != null) _sc.selectedClassroomId.value = cid; }
    Get.snackbar('✅ Auto-filled from Timetable', 'Timetable details automatically applied.',
        backgroundColor: AppTheme.success.withValues(alpha: 0.85), colorText: Colors.white,
        duration: const Duration(seconds: 3), snackPosition: SnackPosition.TOP);
  }

  @override
  void dispose() { _deptCtrl.dispose(); _sectionCtrl.dispose(); _customRadiusCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard, elevation: 0,
        scrolledUnderElevation: 1, surfaceTintColor: Colors.transparent,
        title: Text('Start Attendance Session', style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20), onPressed: () => Get.back()),
      ),
      body: Obx(() {
        if (_sc.isLoading.value && _sc.classrooms.isEmpty) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(),
            const SizedBox(height: 24),
            _secTitle('📍 Class Details'), const SizedBox(height: 12),
            _classroomDropdown(), const SizedBox(height: 14),
            _subjectDropdown(), const SizedBox(height: 14),
            _textField(controller: _deptCtrl, label: 'Department', hint: 'e.g. Computer Science', icon: Icons.domain_outlined),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: _yearDropdown()), const SizedBox(width: 12), Expanded(child: _sectionField())]),
            const SizedBox(height: 24),
            _secTitle('📡 BLE Attendance Range'), const SizedBox(height: 2),
            Text('Select the size of your classroom', style: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 12)),
            const SizedBox(height: 12),
            _rangeSelector(),
            const SizedBox(height: 24),
            _secTitle('⏱️ Session Duration'), const SizedBox(height: 12),
            _durationSelector(),
            const SizedBox(height: 24),
            _secTitle('⚙️ Session Settings'), const SizedBox(height: 12),
            _settingsCard(),
            const SizedBox(height: 24),
            _preview(),
            const SizedBox(height: 24),
            if (_sc.errorMessage.value.isNotEmpty) ...[_errorBanner(_sc.errorMessage.value), const SizedBox(height: 12)],
            _startBtn(),
            const SizedBox(height: 32),
          ]),
        );
      }),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.elevatedShadow),
    child: Row(children: [
      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 28)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Create Attendance Session', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        Text(DateFormat('EEEE, d MMM yyyy — hh:mm a').format(DateTime.now()), style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ])),
    ]),
  );

  Widget _secTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(t, style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)));

  Widget _classroomDropdown() => Obx(() => _dropdownWidget<int>(
    label: 'Classroom', hint: _sc.classrooms.isEmpty ? 'Loading…' : 'Select classroom',
    value: _sc.selectedClassroomId.value, prefixIcon: Icons.meeting_room_outlined,
    items: _sc.classrooms.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text((c['room_name'] as String).replaceAll('CLASSROOM_', ''), style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
    onChanged: (v) => _sc.selectedClassroomId.value = v,
  ));

  Widget _subjectDropdown() => Obx(() => _dropdownWidget<int>(
    label: 'Subject', hint: _sc.subjects.isEmpty ? 'Loading…' : 'Select subject',
    value: _sc.selectedSubjectId.value, prefixIcon: Icons.book_outlined,
    items: _sc.subjects.map((s) => DropdownMenuItem<int>(value: s['id'] as int,
        child: Text([s['subject_name'] as String, if (s['subject_code'] != null) '(${s['subject_code']})'].join(' '), style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
    onChanged: (v) {
      _sc.selectedSubjectId.value = v;
      final sub = _sc.subjects.firstWhereOrNull((s) => s['id'] == v);
      if (sub?['department'] != null) _deptCtrl.text = sub!['department'] as String;
    },
  ));

  Widget _sectionField() => _textField(controller: _sectionCtrl, label: 'Section', hint: 'e.g. A', icon: Icons.group_outlined, maxLength: 3, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))]);

  Widget _yearDropdown() => Obx(() => _dropdownWidget<int>(
    label: 'Year', hint: 'Year', value: _sc.selectedYear.value, prefixIcon: Icons.grade_outlined,
    items: _yearOptions.map((y) => DropdownMenuItem<int>(value: y, child: Text('Year $y', style: const TextStyle(color: AppTheme.textPrimary)))).toList(),
    onChanged: (v) => _sc.selectedYear.value = v ?? 1,
  ));

  Widget _rangeSelector() => Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ...List.generate(_rangePresets.length, (i) {
      final preset = _rangePresets[i];
      final sel = !_useCustomRadius && _rangeIndex == i;
      return GestureDetector(
        onTap: () { setState(() { _rangeIndex = i; _useCustomRadius = false; }); _sc.selectedRadius.value = preset.metres; },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180), margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? AppTheme.primary : AppTheme.cardBorder, width: sel ? 2 : 1),
          ),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: sel ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.bgMuted, borderRadius: BorderRadius.circular(10)),
                child: Icon(preset.icon, color: sel ? AppTheme.primary : AppTheme.textHint, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(preset.label, style: GoogleFonts.poppins(color: sel ? AppTheme.primary : AppTheme.textPrimary, fontWeight: sel ? FontWeight.w700 : FontWeight.w600, fontSize: 14)),
              Text(preset.sublabel, style: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 11)),
            ])),
            if (sel) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
                child: Text('${preset.metres} m', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
        ),
      );
    }),
    GestureDetector(
      onTap: () => setState(() => _useCustomRadius = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180), margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _useCustomRadius ? AppTheme.secondary.withValues(alpha: 0.08) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: _useCustomRadius ? AppTheme.secondary : AppTheme.cardBorder, width: _useCustomRadius ? 2 : 1),
        ),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: _useCustomRadius ? AppTheme.secondary.withValues(alpha: 0.15) : AppTheme.bgMuted, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.tune_rounded, color: _useCustomRadius ? AppTheme.secondary : AppTheme.textHint, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Custom Range', style: GoogleFonts.poppins(color: _useCustomRadius ? AppTheme.secondary : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              if (_isAdmin) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text('Admin', style: GoogleFonts.poppins(color: AppTheme.warning, fontSize: 9, fontWeight: FontWeight.bold)))],
            ]),
            Text('Set your own range (5–100 m)', style: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 11)),
          ])),
        ]),
      ),
    ),
    if (_useCustomRadius) ...[
      const SizedBox(height: 4),
      _textField(controller: _customRadiusCtrl, label: 'Custom range (metres)', hint: '5 – 100', icon: Icons.straighten,
          keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) { final n = int.tryParse(v); if (n != null) _sc.selectedRadius.value = n.clamp(5, 100); }),
    ],
    const SizedBox(height: 8),
    Row(children: [
      const Icon(Icons.info_outline, size: 13, color: AppTheme.textHint), const SizedBox(width: 4),
      Text('RSSI ≈ ${_rssiFor(_sc.selectedRadius.value)} dBm  ·  Range: ${_sc.selectedRadius.value} m', style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
    ]),
  ]));

  String _rssiFor(int r) {
    if (r <= 0) return '-70';
    return (-59 - 25 * (r <= 1 ? 0.0 : r.toDouble() * 0.912)).round().clamp(-100, -40).toString();
  }

  Widget _durationSelector() => Obx(() => Wrap(spacing: 8, runSpacing: 8,
      children: _durationOptions.map((d) => _chip(label: '$d min', selected: _sc.selectedDuration.value == d, onTap: () => _sc.selectedDuration.value = d)).toList()));

  Widget _settingsCard() => Obx(() => Container(
    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
    child: Column(children: [
      _toggleTile(icon: Icons.bluetooth_rounded, iconColor: AppTheme.primary, title: 'BLE Required', subtitle: 'Students must be within BLE range', value: _sc.bleRequired.value, onChanged: (v) => _sc.bleRequired.value = v),
      const Divider(height: 1, color: AppTheme.cardBorder),
      _toggleTile(icon: Icons.face_retouching_natural_rounded, iconColor: AppTheme.secondary, title: 'Face Verification', subtitle: 'Require face scan for attendance', value: _sc.faceRequired.value, onChanged: (v) => _sc.faceRequired.value = v),
      const Divider(height: 1, color: AppTheme.cardBorder),
      _toggleTile(icon: Icons.timer_off_outlined, iconColor: AppTheme.warning, title: 'Auto End Session', subtitle: 'Auto-close when duration expires', value: _sc.autoEndSession.value, onChanged: (v) => _sc.autoEndSession.value = v),
    ]),
  ));

  Widget _toggleTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool value, required void Function(bool) onChanged}) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 11)),
      ])),
      Switch(value: value, onChanged: onChanged, activeThumbColor: iconColor),
    ]));

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: selected ? AppTheme.primary : AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? AppTheme.primary : AppTheme.cardBorder)),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
    ));

  Widget _preview() => Obx(() {
    if (_sc.selectedClassroomId.value == null || _sc.selectedSubjectId.value == null) return const SizedBox.shrink();
    final name = _sc.generatedSessionName;
    final now  = DateTime.now();
    final fmt  = DateFormat('hh:mm a');
    final rangeLabel = _useCustomRadius ? '${_sc.selectedRadius.value} m (Custom)' : '${_rangePresets[_rangeIndex].metres} m · ${_rangePresets[_rangeIndex].label}';
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SESSION PREVIEW', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        _prow('Name',     name.isEmpty ? 'Fill form above' : name),
        _prow('Start',    fmt.format(now)),
        _prow('End',      fmt.format(now.add(Duration(minutes: _sc.selectedDuration.value)))),
        _prow('Range',    rangeLabel),
        _prow('Duration', '${_sc.selectedDuration.value} min'),
        _prow('BLE',      _sc.bleRequired.value ? '✅ Required' : '❌ Off'),
        _prow('Face',     _sc.faceRequired.value ? '✅ Required' : '❌ Off'),
        _prow('Auto End', _sc.autoEndSession.value ? '✅ On' : '❌ Off'),
      ]),
    );
  });

  Widget _prow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
    SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 12))),
    const Text('  ·  ', style: TextStyle(color: AppTheme.textHint)),
    Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
  ]));

  Widget _startBtn() => Obx(() => SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(
    onPressed: _sc.isStarting.value ? null : () async { final ok = await _sc.startSession(); if (ok) Get.offNamed(AppConstants.routeActiveSession); },
    icon: _sc.isStarting.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_circle_filled, size: 22),
    label: Text(_sc.isStarting.value ? 'Starting…' : 'Start Session', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppTheme.primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  )));

  Widget _errorBanner(String msg) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error.withValues(alpha: 0.4))),
    child: Row(children: [const Icon(Icons.error_outline, color: AppTheme.error, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg, style: const TextStyle(color: AppTheme.error, fontSize: 13)))]));

  Widget _dropdownWidget<T>({required String label, required String hint, required T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged, IconData? prefixIcon}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
      Container(decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardBorder)),
        child: DropdownButtonFormField<T>(initialValue: value, decoration: InputDecoration(prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.textHint, size: 20) : null, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), hintText: hint, hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
          dropdownColor: AppTheme.bgCard, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14), items: items, onChanged: onChanged)),
    ]);

  Widget _textField({required TextEditingController controller, required String label, required String hint, required IconData icon, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, int? maxLength, void Function(String)? onChanged}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
      TextField(controller: controller, keyboardType: keyboardType, inputFormatters: inputFormatters, maxLength: maxLength, onChanged: onChanged, style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(prefixIcon: Icon(icon, color: AppTheme.textHint, size: 20), hintText: hint, hintStyle: const TextStyle(color: AppTheme.textHint), filled: true, fillColor: AppTheme.bgCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)), counterText: '')),
    ]);
}
