// lib/screens/putaway/putaway_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import 'putaway_widgets.dart';

// ── Station constants (STN only) ─────────────
final _kStations = [
  StationInfo(
    id: 'STN-1',
    label: 'Station 1',
    color: AppTheme.primary,
    icon: MdiIcons.warehouse,
  ),
  StationInfo(
    id: 'STN-2',
    label: 'Station 2',
    color: AppTheme.teal,
    icon: MdiIcons.warehouse,
  ),
  StationInfo(
    id: 'STN-3',
    label: 'Station 3',
    color: AppTheme.success,
    icon: MdiIcons.warehouse,
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
    final busy = _stationStatus[station.id];
    if (busy != null) return;

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
                    Row(
                      children: [
                        Icon(
                          MdiIcons.barcodeScan,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
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
              SectionHeader(title: 'เลือก Station', icon: MdiIcons.viewGridOutline),
              const SizedBox(height: 12),

              Row(
                children: [
                  for (int i = 0; i < _kStations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: StationCard(
                        station: _kStations[i],
                        isDispatching: _stationStatus.containsKey(
                          _kStations[i].id,
                        ),
                        busyPalletId:
                            _stationStatus[_kStations[i].id]?['palletId']
                                as String?,
                        busyDestination:
                            _stationStatus[_kStations[i].id]?['destination']
                                as String?,
                        onTap: () => _openStationPopup(_kStations[i]),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // // ── Legend ────────────────────────
              // WmsCard(
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text(
              //         'การทำงาน',
              //         style: TextStyle(
              //           fontWeight: FontWeight.w700,
              //           fontSize: 13,
              //           color: AppTheme.textPrimary(context),
              //         ),
              //       ),
              //       const SizedBox(height: 8),
              //       _LegendRow(
              //         icon: Icons.domain,
              //         color: AppTheme.primary,
              //         text: 'FG → เก็บเข้า ASRS หรือ Replenish Rack',
              //       ),
              //       const SizedBox(height: 6),
              //       _LegendRow(
              //         icon: Icons.build_circle,
              //         color: AppTheme.warning,
              //         text: 'PW → ส่งจุด Prework หรือเก็บ ASRS',
              //       ),
              //       const SizedBox(height: 6),
              //       _LegendRow(
              //         icon: Icons.wrap_text,
              //         color: AppTheme.secondary,
              //         text: 'เลือกพัน Pallet ผ่าน Wrapping Machine ก่อนเข้า ASRS',
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

// class _LegendRow extends StatelessWidget {
//   final IconData icon;
//   final Color color;
//   final String text;

//   const _LegendRow({
//     required this.icon,
//     required this.color,
//     required this.text,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, color: color, size: 16),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Text(
//             text,
//             style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
//           ),
//         ),
//       ],
//     );
//   }
// }
