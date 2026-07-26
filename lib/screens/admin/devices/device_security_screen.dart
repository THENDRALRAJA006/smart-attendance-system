// Device Security Screen — device logs, duplicates, bindings
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class DeviceSecurityScreen extends StatefulWidget {
  const DeviceSecurityScreen({super.key});
  @override State<DeviceSecurityScreen> createState() => _DSS();
}

class _DSS extends State<DeviceSecurityScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final AdminController _ctrl = Get.find();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _ctrl.fetchDeviceLogs();
    _ctrl.fetchDuplicateDevices();
    _ctrl.fetchDeviceBindings();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Container(
        color: AppTheme.cardBg,
        child: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [Tab(text: 'Session Logs'), Tab(text: 'Duplicates'), Tab(text: 'Bindings')],
        ),
      ),
      Expanded(child: TabBarView(controller: _tab, children: [_logs(), _duplicates(), _bindings()])),
    ]);

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Device Security'),
          backgroundColor: AppTheme.bgCard,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  // ─── Session Logs ──────────────────────────────────────────
  Widget _logs() => Obx(() {
    if (_ctrl.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_ctrl.deviceLogs.isEmpty) return const Center(child: Text('No device logs', style: TextStyle(color: AppTheme.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ctrl.deviceLogs.length,
      itemBuilder: (_, i) {
        final d = _ctrl.deviceLogs[i];
        return _logTile(d);
      },
    );
  });

  Widget _logTile(DeviceLogModel d) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder)),
    child: Row(children: [
      const Icon(Icons.phone_android_rounded, color: AppTheme.primary, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.studentName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        Text('${d.regNo} • Session #${d.sessionId}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        Text('Device: ${d.deviceId}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ])),
      Text(d.attendanceTime.toString().substring(0, 16), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
    ]),
  );

  // ─── Duplicate Devices ─────────────────────────────────────
  Widget _duplicates() => Column(children: [
    Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3))),
        child: const Row(children: [
          Icon(Icons.warning_rounded, color: AppTheme.error),
          SizedBox(width: 8),
          Expanded(child: Text('Devices used by multiple students in the same session — potential fraud.',
              style: TextStyle(color: AppTheme.error, fontSize: 12))),
        ]),
      ),
    ),
    Expanded(child: Obx(() {
      if (_ctrl.duplicateDevices.isEmpty) {
        return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, color: Colors.green, size: 48),
          SizedBox(height: 8),
          Text('No duplicates detected', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
        ]));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        itemCount: _ctrl.duplicateDevices.length,
        itemBuilder: (_, i) {
          final d = _ctrl.duplicateDevices[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4))),
            child: Row(children: [
              const Icon(Icons.device_unknown_rounded, color: AppTheme.error, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Device: ${d['device_id'] ?? ""}', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Session #${d['session_id']} • ${d['student_count']} students used this device',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
            ]),
          );
        },
      );
    })),
  ]);

  // ─── Device Bindings ───────────────────────────────────────
  Widget _bindings() => Obx(() {
    if (_ctrl.deviceBindings.isEmpty) return const Center(child: Text('No device bindings', style: TextStyle(color: AppTheme.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ctrl.deviceBindings.length,
      itemBuilder: (_, i) {
        final b = _ctrl.deviceBindings[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder)),
          child: Row(children: [
            CircleAvatar(backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.phone_android_rounded, color: AppTheme.primary, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.studentName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              Text(b.regNo, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text('${b.manufacturer ?? ""} ${b.model ?? ""}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Text('Android ID: ${b.androidId}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ])),
            IconButton(
              icon: const Icon(Icons.link_off_rounded, color: AppTheme.error, size: 22),
              onPressed: () => _confirmRemoveBinding(b),
            ),
          ]),
        );
      },
    );
  });

  void _confirmRemoveBinding(DeviceBindingModel b) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Remove Binding?', style: TextStyle(color: AppTheme.textPrimary)),
      content: Text('Remove device binding for ${b.studentName}?\nThey will need to re-register their device.',
          style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () async { Get.back(); await _ctrl.removeDeviceBinding(b.id); },
          child: const Text('Remove', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}
