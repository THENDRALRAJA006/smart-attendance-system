// Audit Logs Screen — immutable trail with filter by action/type/date
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});
  @override State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AdminController _ctrl = Get.find();
  final _actionCtrl = TextEditingController();
  String? _targetType;

  final _targetTypes = [
    null, 'student', 'faculty', 'attendance', 'session',
    'face', 'device_binding', 'ble_beacon', 'settings', 'classroom',
  ];

  @override
  void initState() { super.initState(); _ctrl.fetchAuditLogs(); }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      _filterBar(),
      Expanded(
        child: Obx(() {
          if (_ctrl.isLoading.value && _ctrl.auditLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (_ctrl.auditLogs.isEmpty) {
            return const Center(child: Text('No audit logs found',
                style: TextStyle(color: AppTheme.textSecondary)));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            itemCount: _ctrl.auditLogs.length,
            itemBuilder: (_, i) => _logCard(_ctrl.auditLogs[i]),
          );
        }),
      ),
    ]);

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('Audit Logs'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  Widget _filterBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _actionCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filter by action...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
              filled: true, fillColor: AppTheme.cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.cardBorder)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _applyFilters,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _clearFilters,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder)),
            child: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _targetTypes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final t = _targetTypes[i];
            final selected = _targetType == t;
            return GestureDetector(
              onTap: () { setState(() => _targetType = t); _applyFilters(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: selected ? AppTheme.primary : AppTheme.cardBorder),
                ),
                child: Text(t ?? 'All',
                    style: TextStyle(
                        color: selected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            );
          },
        ),
      ),
    ]),
  );

  Widget _logCard(AuditLogModel log) {
    final color = _actionColor(log.action);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Text(log.icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.actionLabel,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 12),
            const SizedBox(width: 4),
            Text(log.actorName ?? 'System',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            if (log.targetType != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(log.targetType!,
                    style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          if (log.detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(log.detail!,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_formatDate(log.createdAt),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          Text(_formatTime(log.createdAt),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ]),
      ]),
    );
  }

  void _applyFilters() {
    _ctrl.fetchAuditLogs(
      action: _actionCtrl.text.isNotEmpty ? _actionCtrl.text : null,
      targetType: _targetType,
    );
  }

  void _clearFilters() {
    _actionCtrl.clear();
    setState(() => _targetType = null);
    _ctrl.fetchAuditLogs();
  }

  Color _actionColor(String action) {
    if (action.contains('delete') || action.contains('remove')) return AppTheme.error;
    if (action.contains('suspend')) return Colors.orange;
    if (action.contains('create')) return Colors.green;
    if (action.contains('activate')) return const Color(0xFF06D6A0);
    return AppTheme.primary;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
