// Settings Screen — key-value system settings grouped by category
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AdminController _ctrl = Get.find();
  // Local editing state: key → TextEditingController
  final Map<String, TextEditingController> _editors = {};
  bool _dirty = false;

  @override
  void initState() { super.initState(); _ctrl.fetchSettings(); }

  @override
  void dispose() {
    for (final c in _editors.values) { c.dispose(); }
    super.dispose();
  }

  void _initEditors(Map<String, List<SystemSettingModel>> settings) {
    for (final items in settings.values) {
      for (final s in items) {
        if (!_editors.containsKey(s.key)) {
          _editors[s.key] = TextEditingController(text: s.value ?? '');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          const Text('System Settings', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_dirty)
            GestureDetector(
              onTap: _saveAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Text('Save All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Obx(() {
          if (_ctrl.isLoading.value && _ctrl.settings.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          _initEditors(_ctrl.settings);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: _ctrl.settings.entries.map((entry) =>
              _categorySection(entry.key, entry.value)
            ).toList(),
          );
        }),
      ),
    ]);

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  Widget _categorySection(String category, List<SystemSettingModel> items) {
    final icon = _categoryIcon(category);
    final color = _categoryColor(category);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(category.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ]),
          ),
          ...items.map((s) => _settingRow(s)),
        ],
      ),
    );
  }

  Widget _settingRow(SystemSettingModel s) {
    final ctrl = _editors[s.key];
    if (ctrl == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.label ?? s.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(s.key, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onChanged: (_) => setState(() => _dirty = true),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: AppTheme.bgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primary)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _saveAll() async {
    final updates = <String, String>{};
    for (final e in _editors.entries) {
      updates[e.key] = e.value.text;
    }
    final ok = await _ctrl.updateSettings(updates);
    if (ok) {
      setState(() => _dirty = false);
      Get.snackbar('Saved', 'Settings updated successfully',
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12));
    } else {
      Get.snackbar('Error', _ctrl.errorMessage.value,
          backgroundColor: AppTheme.error.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      _ctrl.clearMessages();
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'attendance': return Icons.fact_check_rounded;
      case 'face':       return Icons.face_rounded;
      case 'ble':        return Icons.bluetooth_rounded;
      case 'security':   return Icons.security_rounded;
      default:           return Icons.settings_rounded;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'attendance': return const Color(0xFF48CAE4);
      case 'face':       return const Color(0xFFFFB703);
      case 'ble':        return const Color(0xFF06D6A0);
      case 'security':   return const Color(0xFFFF6B6B);
      default:           return AppTheme.primary;
    }
  }
}
