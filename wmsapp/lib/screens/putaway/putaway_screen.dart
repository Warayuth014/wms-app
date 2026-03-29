// lib/screens/putaway/putaway_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import 'putaway_widgets.dart';

// ── Station constants (STN only) ─────────────
const _kStations = [
  StationInfo(
    id: 'STN-1',
    label: 'Station 1',
    color: AppTheme.primary,
    icon: Icons.warehouse,
  ),
  StationInfo(
    id: 'STN-2',
    label: 'Station 2',
    color: AppTheme.teal,
    icon: Icons.warehouse,
  ),
  StationInfo(
    id: 'STN-3',
    label: 'Station 3',
    color: AppTheme.success,
    icon: Icons.warehouse,
  ),
];

// =============================================
// PutawayScreen — STN-1, STN-2, STN-3 only
// =============================================
class PutawayScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PutawayScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PutawayScreen> createState() => _PutawayScreenState();
}

class _PutawayScreenState extends State<PutawayScreen> {
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

    final station = _kStations.where((s) => s.id == raw).firstOrNull;
    if (station == null) {
      showErrorDialog(
        context,
        message: 'ไม่พบ Station: $raw\nStation ที่รองรับ: STN-1, STN-2, STN-3',
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
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Putaway — จัดเก็บสินค้า',
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
                          color: AppTheme.primary,
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
                      hint: 'เช่น STN-1',
                      controller: _stationController,
                      onSubmit: _onStationBarcodeScan,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Station Grid ──────────────────
              SectionHeader(title: 'เลือก Station', icon: Icons.grid_view),
              const SizedBox(height: 12),

              Row(
                children: [
                  for (int i = 0; i < _kStations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 140,
                        child: StationCard(
                          station: _kStations[i],
                          isDispatching: _dispatchingStations.contains(
                            _kStations[i].id,
                          ),
                          onTap: () => _openStationPopup(_kStations[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

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
                      icon: Icons.domain,
                      color: AppTheme.primary,
                      text: 'FG → เก็บเข้า ASRS หรือ Replenish Rack',
                    ),
                    const SizedBox(height: 6),
                    _LegendRow(
                      icon: Icons.build_circle,
                      color: AppTheme.warning,
                      text: 'PW → ส่งจุด Prework หรือเก็บ ASRS',
                    ),
                    const SizedBox(height: 6),
                    _LegendRow(
                      icon: Icons.wrap_text,
                      color: AppTheme.secondary,
                      text: 'เลือกพัน Pallet ผ่าน Wrapping Machine ก่อนเข้า ASRS',
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
