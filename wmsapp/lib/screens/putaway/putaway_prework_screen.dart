// lib/screens/putaway/putaway_prework_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
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
  final Set<String> _dispatchingStations = {};
  final Map<String, Timer> _dispatchTimers = {};

  @override
  void dispose() {
    _stationController.dispose();
    for (final t in _dispatchTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _onPutawayConfirmed(String stationId) {
    setState(() => _dispatchingStations.add(stationId));
    _dispatchTimers[stationId]?.cancel();
    _dispatchTimers[stationId] = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _dispatchingStations.remove(stationId));
      _dispatchTimers.remove(stationId);
    });
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StationSheet(
        station: station,
        userId: widget.userId,
        onConfirmed: () => _onPutawayConfirmed(station.id),
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
      appBar: WmsAppBar(
        title: 'Putaway Prework',
        userName: widget.fullName,
      ),
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
                          SizedBox(
                            height: 130,
                            child: StationCard(
                              station: s,
                              isDispatching: _dispatchingStations.contains(
                                s.id,
                              ),
                              onTap: () => _openStationPopup(s),
                            ),
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
                          SizedBox(
                            height: 130,
                            child: StationCard(
                              station: s,
                              isDispatching: _dispatchingStations.contains(
                                s.id,
                              ),
                              onTap: () => _openStationPopup(s),
                            ),
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
                      text: 'รับ Pallet — เรียก PW Pallet จาก ASRS มาที่ Prework',
                    ),
                    const SizedBox(height: 6),
                    _LegendRow(
                      icon: Icons.upload,
                      color: _kColorSend,
                      text: 'ส่ง Pallet — Convert PW→FG แล้วส่งเข้า ASRS',
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
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey(context),
            ),
          ),
        ),
      ],
    );
  }
}
