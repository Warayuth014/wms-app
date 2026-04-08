// lib/screens/unload/unload_menu/unload_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../putaway/shared/putaway_shared_widgets.dart';
import '../unload_session/unload_session_sheet.dart';

final _kUnloadStations = <StationInfo>[
  StationInfo(
    id: 'UNL-1',
    label: 'Unload 1',
    color: const Color(0xFF1976D2),
    icon: MdiIcons.trayArrowUp,
  ),
  StationInfo(
    id: 'UNL-2',
    label: 'Unload 2',
    color: const Color(0xFF009688),
    icon: MdiIcons.trayArrowUp,
  ),
  StationInfo(
    id: 'UNL-3',
    label: 'Unload 3',
    color: const Color(0xFF4CAF50),
    icon: MdiIcons.trayArrowUp,
  ),
];

class UnloadMenuScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const UnloadMenuScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<UnloadMenuScreen> createState() => _UnloadMenuScreenState();
}

class _UnloadMenuScreenState extends State<UnloadMenuScreen> {
  final _stationController = TextEditingController();

  @override
  void dispose() {
    _stationController.dispose();
    super.dispose();
  }

  void _onStationBarcodeScan() {
    final raw = _stationController.text.trim().toUpperCase();
    _stationController.clear();
    if (raw.isEmpty) return;

    final station = _kUnloadStations.where((s) => s.id == raw).firstOrNull;
    if (station == null) {
      showErrorDialog(
        context,
        message:
            'Station not found: $raw\nSupported stations: UNL-1, UNL-2, UNL-3',
      );
      return;
    }
    _openStation(station);
  }

  void _openStation(StationInfo station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnloadSessionSheet(
        station: station,
        userId: widget.userId,
        fullName: widget.fullName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Replenishment - Unload',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UnloadStationScanCard(
                controller: _stationController,
                onSubmit: _onStationBarcodeScan,
              ),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'เลือก Station',
                icon: MdiIcons.viewGridOutline,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < _kUnloadStations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: StationCard(
                        station: _kUnloadStations[i],
                        onTap: () => _openStation(_kUnloadStations[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnloadStationScanCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _UnloadStationScanCard({
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.barcodeScan, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'สแกนบาร์โค้ด Station',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'หรือกดที่รูป Station ด้านล่าง',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Station ID',
            hint: 'เช่น UNL-1',
            controller: controller,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}
