// BLE Management Screen
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/admin_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';

class BleManagementScreen extends StatefulWidget {
  const BleManagementScreen({super.key});
  @override State<BleManagementScreen> createState() => _BleManagementScreenState();
}

class _BleManagementScreenState extends State<BleManagementScreen> {
  final AdminController _ctrl = Get.find();

  @override
  void initState() {
    super.initState();
    _ctrl.fetchBleBeacons();
    _ctrl.fetchClassrooms();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Obx(() => Text('${_ctrl.bleBeacons.length} BLE Beacons',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))),
              const Spacer(),
              _btn(() => _showAddDialog()),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (_ctrl.bleBeacons.isEmpty) {
              return const Center(
                  child: Text('No BLE beacons configured',
                      style: TextStyle(color: AppTheme.textSecondary)));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _ctrl.bleBeacons.length,
              itemBuilder: (_, i) => _card(_ctrl.bleBeacons[i]),
            );
          }),
        ),
      ],
    );

    if (Navigator.of(context).canPop()) {
      return Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          title: const Text('BLE Devices'),
          backgroundColor: AppTheme.bgPage,
          elevation: 0,
        ),
        body: body,
      );
    }
    return body;
  }

  Widget _card(BleBeaconModel b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: b.isActive
                ? const Color(0xFF06D6A0).withValues(alpha: 0.4)
                : AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (b.isActive
                        ? const Color(0xFF06D6A0)
                        : AppTheme.textSecondary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bluetooth_rounded,
                  color: b.isActive
                      ? const Color(0xFF06D6A0)
                      : AppTheme.textSecondary,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.beaconName,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text('Classroom #${b.classroomId}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: b.isActive,
              activeThumbColor: const Color(0xFF06D6A0),
              onChanged: (_) => _ctrl.toggleBleBeacon(b.id),
            ),
          ]),
          const SizedBox(height: 10),
          _row('UUID', b.beaconUuid),
          _row('RSSI Threshold', '${b.rssiThreshold} dBm'),
          if (b.txPower != null) _row('TX Power', '${b.txPower} dBm'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                onPressed: () => _showEditDialog(b),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                onPressed: () => _confirmDelete(b),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12))),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  void _showAddDialog() => _showForm(null);
  void _showEditDialog(BleBeaconModel b) => _showForm(b);

  void _showForm(BleBeaconModel? beacon) {
    final uuidCtrl  = TextEditingController(text: beacon?.beaconUuid ?? '');
    final nameCtrl  = TextEditingController(text: beacon?.beaconName ?? '');
    final txCtrl    = TextEditingController(
        text: beacon?.txPower?.toString() ?? '');
    final classCtrl = TextEditingController(
        text: beacon?.classroomId.toString() ?? '');
    final isEdit = beacon != null;

    // BLE Range state
    const rangeOptions = [10, 15, 20, 25];
    // Convert existing rssi_threshold back to approx metres for default selection
    int selectedRange = 20;
    bool useCustomRange = false;
    final customRangeCtrl = TextEditingController();

    if (beacon != null) {
      // rssi → approx metres reverse: d = 10^((TxPower - RSSI) / (10*n))
      final rssi = beacon.rssiThreshold;
      final approxM = ((rssi + 59).abs() / 22.8).round().clamp(5, 100);
      if (rangeOptions.contains(approxM)) {
        selectedRange = approxM;
      } else {
        useCustomRange = true;
        customRangeCtrl.text = approxM.toString();
      }
    }

    int rssiFor(int metres) {
      if (metres <= 0) return -80;
      return (-59 - 25 * (metres <= 1 ? 0.0 : metres * 0.912))
          .round()
          .clamp(-100, -40);
    }

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, ss) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit BLE Beacon' : 'Add BLE Beacon',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _field(nameCtrl, 'Beacon Name'),
                _field(uuidCtrl, 'Beacon UUID'),
                _field(classCtrl, 'Classroom ID',
                    keyboard: TextInputType.number),
                _field(txCtrl, 'TX Power in dBm (optional)',
                    keyboard: TextInputType.number),

                // ── BLE Range Selector ──────────────────────
                const SizedBox(height: 4),
                const Text('BLE Detection Range',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...rangeOptions.map((r) => GestureDetector(
                          onTap: () => ss(() {
                            selectedRange = r;
                            useCustomRange = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: (!useCustomRange && selectedRange == r)
                                  ? AppTheme.primary
                                  : AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (!useCustomRange && selectedRange == r)
                                    ? AppTheme.primary
                                    : AppTheme.cardBorder,
                              ),
                            ),
                            child: Text('$r m',
                                style: TextStyle(
                                  color: (!useCustomRange && selectedRange == r)
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontWeight: (!useCustomRange && selectedRange == r)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                )),
                          ),
                        )),
                    GestureDetector(
                      onTap: () => ss(() => useCustomRange = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: useCustomRange
                              ? AppTheme.secondary
                              : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: useCustomRange
                                ? AppTheme.secondary
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Text('Custom',
                            style: TextStyle(
                              color: useCustomRange
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: useCustomRange
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            )),
                      ),
                    ),
                  ],
                ),
                if (useCustomRange) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customRangeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) ss(() => selectedRange = n.clamp(5, 100));
                    },
                    decoration: InputDecoration(
                      labelText: 'Custom range (metres, 5–100)',
                      labelStyle:
                          const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.straighten,
                          color: AppTheme.textHint, size: 18),
                      filled: true,
                      fillColor: AppTheme.cardBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppTheme.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppTheme.cardBorder)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text(
                    'RSSI ≈ ${rssiFor(useCustomRange ? (int.tryParse(customRangeCtrl.text) ?? selectedRange) : selectedRange)} dBm  ·  Range: ${useCustomRange ? (customRangeCtrl.text.isEmpty ? selectedRange : customRangeCtrl.text) : selectedRange} m',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11),
                  ),
                ]),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final effectiveRange = useCustomRange
                          ? (int.tryParse(customRangeCtrl.text) ?? selectedRange)
                          : selectedRange;
                      final data = {
                        'beacon_name':    nameCtrl.text,
                        'beacon_uuid':    uuidCtrl.text,
                        'classroom_id':   int.tryParse(classCtrl.text) ?? 0,
                        'rssi_threshold': rssiFor(effectiveRange),
                        if (txCtrl.text.isNotEmpty)
                          'tx_power': int.tryParse(txCtrl.text),
                      };
                      bool ok;
                      if (isEdit) {
                        ok = await _ctrl.updateBleBeacon(beacon.id, data);
                      } else {
                        ok = await _ctrl.addBleBeacon(data);
                      }
                      if (ok) Get.back();
                    },
                    child: Text(isEdit ? 'Save Changes' : 'Add Beacon',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _confirmDelete(BleBeaconModel b) {
    Get.dialog(AlertDialog(
      backgroundColor: AppTheme.bgDark,
      title: const Text('Delete Beacon?',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Text('Delete "${b.beaconName}"?',
          style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () async {
            Get.back();
            await _ctrl.deleteBleBeacon(b.id);
          },
          child: const Text('Delete',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.cardBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.cardBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.cardBorder)),
          ),
        ),
      );

  Widget _btn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('+ Add Beacon',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      );
}
