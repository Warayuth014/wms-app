// lib/screens/putaway/putaway_prework_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import 'putaway_widgets.dart';

// ── Station constants (PW-STN only) ──────────
const _kColorReceive = Color(0xFF00796B); // teal เข้ม — รับ pallet
const _kColorSend = Color(0xFFD84315); // ส้มแดง — ส่ง pallet

const _kPWStations = [
  StationInfo(
    id: 'PW-STN-1',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: Icons.download,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-2',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: Icons.upload,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  StationInfo(
    id: 'PW-STN-3',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: Icons.download,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-4',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: Icons.upload,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  StationInfo(
    id: 'PW-STN-5',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: Icons.download,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-6',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: Icons.upload,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
];

// =============================================
// PutawayPreworkScreen — PW-STN-1 ~ PW-STN-6
// =============================================
class PutawayPreworkScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PutawayPreworkScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PutawayPreworkScreen> createState() => _PutawayPreworkScreenState();
}

class _PutawayPreworkScreenState extends State<PutawayPreworkScreen> {
  final _stationController = TextEditingController();
  final _api = ApiService();

  // stationId → { palletId, destination, items }
  Map<String, Map<String, dynamic>> _stationStatus = {};

  @override
  void initState() {
    super.initState();
    _loadStationStatus();
  }

  @override
  void dispose() {
    _stationController.dispose();
    super.dispose();
  }

  Future<void> _loadStationStatus() async {
    final result = await _api.getStationStatus();
    if (!mounted) return;
    if (result.success) {
      final map = <String, Map<String, dynamic>>{};
      for (final s in result.data!) {
        map[s['stationId'] as String] = s;
      }
      setState(() => _stationStatus = map);
    }
  }

  void _onStationBarcodeScan() {
    final raw = _stationController.text.trim().toUpperCase();
    _stationController.clear();
    if (raw.isEmpty) return;

    final station = _kPWStations.where((s) => s.id == raw).firstOrNull;
    if (station == null) {
      showErrorDialog(
        context,
        message:
            'ไม่พบ Station: $raw\n'
            'Station ที่รองรับ: PW-STN-1 ~ PW-STN-6',
      );
      return;
    }

    _openStationPopup(station);
  }

  void _openStationPopup(StationInfo station) {
    final busy = _stationStatus[station.id];
    if (busy != null) {
      _showBusyDialog(station, busy);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationSheet(
        station: station,
        userId: widget.userId,
        onConfirmed: () {
          _loadStationStatus();
        },
      ),
    );
  }

  void _showBusyDialog(StationInfo station, Map<String, dynamic> busy) {
    final palletId = busy['palletId'] as String;
    final dest = busy['destination'] as String;
    final items = busy['items'] as List? ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
            const SizedBox(width: 8),
            Text(
              '${station.id} ไม่ว่าง',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(label: 'Pallet', value: palletId),
                  InfoRow(label: 'ปลายทาง', value: dest),
                  InfoRow(
                    label: 'สถานะ',
                    value: station.pwRole == PWRole.receive
                        ? 'AMR กำลังนำ Pallet มา'
                        : 'AGV กำลังมารับ',
                  ),
                ],
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'สินค้าบน Pallet:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${item['partId']} — ${item['itemDesc']}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item['qty']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadStationStatus();
            },
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // แบ่ง odd=รับ (index 0,2,4) — even=ส่ง (index 1,3,5)
    final receiveStations = _kPWStations
        .where((s) => s.pwRole == PWRole.receive)
        .toList();
    final sendStations = _kPWStations
        .where((s) => s.pwRole == PWRole.send)
        .toList();

    return Scaffold(
      appBar: WmsAppBar(title: 'Putaway Prework', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Scan station barcode ──────────
              WmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: _kColorReceive,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'สแกนบาร์โค้ด Station',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'หรือกดที่รูป Station ด้านล่าง',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ScanTextField(
                      label: 'Station ID',
                      hint: 'เช่น PW-STN-1',
                      controller: _stationController,
                      onSubmit: _onStationBarcodeScan,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Receive / Send columns ────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── รับ column ──
                  Expanded(
                    child: Column(
                      children: [
                        _ColumnHeader(
                          label: 'รับ Pallet',
                          icon: Icons.download,
                          color: _kColorReceive,
                        ),
                        const SizedBox(height: 10),
                        for (final s in receiveStations) ...[
                          StationCard(
                            station: s,
                            isDispatching: _stationStatus.containsKey(s.id),
                            busyPalletId: _stationStatus[s.id]
                                ?['palletId'] as String?,
                            busyDestination: _stationStatus[s.id]
                                ?['destination'] as String?,
                            onTap: () => _openStationPopup(s),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── ส่ง column ──
                  Expanded(
                    child: Column(
                      children: [
                        _ColumnHeader(
                          label: 'ส่ง Pallet',
                          icon: Icons.upload,
                          color: _kColorSend,
                        ),
                        const SizedBox(height: 10),
                        for (final s in sendStations) ...[
                          StationCard(
                            station: s,
                            isDispatching: _stationStatus.containsKey(s.id),
                            busyPalletId: _stationStatus[s.id]
                                ?['palletId'] as String?,
                            busyDestination: _stationStatus[s.id]
                                ?['destination'] as String?,
                            onTap: () => _openStationPopup(s),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // ── Legend ────────────────────────
              WmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'การทำงาน',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      icon: Icons.download,
                      color: _kColorReceive,
                      text:
                          'รับ Pallet — เรียก PW Pallet จาก ASRS มาที่ Prework',
                    ),
                    const SizedBox(height: 6),
                    _LegendRow(
                      icon: Icons.upload,
                      color: _kColorSend,
                      text: 'ส่ง Pallet — ติดสติ๊กเกอร์ แล้วส่งเข้า ASRS',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Column header badge ───────────────────────
class _ColumnHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ColumnHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _LegendRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
          ),
        ),
      ],
    );
  }
}
