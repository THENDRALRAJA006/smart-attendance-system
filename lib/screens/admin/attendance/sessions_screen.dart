// Sessions Screen — list + close action
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final AdminController _ctrl = Get.find();
  bool? _activeFilter;

  @override
  void initState() { super.initState(); _ctrl.fetchSessions(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        Obx(() => Text('${_ctrl.sessionsTotal.value} Sessions',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
        const Spacer(),
        _chip('All',     _activeFilter == null,  () { setState(() { _activeFilter = null; }); _ctrl.fetchSessions(); }),
        const SizedBox(width: 6),
        _chip('Active',  _activeFilter == true,  () { setState(() { _activeFilter = true; }); _ctrl.fetchSessions(isActive: true); }),
        const SizedBox(width: 6),
        _chip('Closed',  _activeFilter == false, () { setState(() { _activeFilter = false; }); _ctrl.fetchSessions(isActive: false); }),
      ]),
    ),
    Expanded(child: Obx(() {
      if (_ctrl.isLoading.value) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
      if (_ctrl.sessions.isEmpty) return const Center(child: Text('No sessions', style: TextStyle(color: AppTheme.textSecondary)));
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        itemCount: _ctrl.sessions.length,
        itemBuilder: (_, i) => _card(_ctrl.sessions[i]),
      );
    })),
  ]);

  Widget _card(AdminSessionModel s) {
    final dur = s.duration;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.isActive ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: s.isActive ? Colors.green : AppTheme.textSecondary, shape: BoxShape.circle),
          ),
          Text('Session #${s.id}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (s.isActive ? Colors.green : AppTheme.textSecondary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(s.isActive ? 'LIVE' : 'CLOSED',
                style: TextStyle(color: s.isActive ? Colors.green : AppTheme.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Started: ${s.startTime.toString().substring(0, 16)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        if (s.endTime != null)
          Text('Ended: ${s.endTime.toString().substring(0, 16)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Row(children: [
          _stat(Icons.people_rounded, '${s.attendanceCount} Attended'),
          const SizedBox(width: 12),
          _stat(Icons.timer_rounded, '${dur.inMinutes}m ${dur.inSeconds % 60}s'),
          const Spacer(),
          if (s.isActive)
            GestureDetector(
              onTap: () => _confirmClose(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                ),
                child: const Text('Close Session',
                    style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ]),
    );
  }

  void _confirmClose(AdminSessionModel s) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Close Session?', style: TextStyle(color: AppTheme.textPrimary)),
      content: Text('Close Session #${s.id}? Students will no longer be able to mark attendance.',
          style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () async { Get.back(); await _ctrl.closeSession(s.id); },
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _stat(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppTheme.textSecondary, size: 14),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ],
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.primary : AppTheme.cardBorder),
      ),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}
