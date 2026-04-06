import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../services/api_service.dart';
import '../../../services/signalr_service.dart';
import '../../../widgets/common_widgets.dart';
import '../shared/putaway_shared_widgets.dart';
import 'widgets/putaway_station_grid.dart';
import 'widgets/putaway_station_scan_card.dart';

final _kStations = [
  StationInfo(
    id: 'STN-1',
    label: 'Station 1',
    color: const Color(0xFF1976D2),
    icon: MdiIcons.warehouse,
  ),
  StationInfo(
    id: 'STN-2',
    label: 'Station 2',
    color: const Color(0xFF009688),
    icon: MdiIcons.warehouse,
  ),
  StationInfo(
    id: 'STN-3',
    label: 'Station 3',
    color: const Color(0xFF4CAF50),
    icon: MdiIcons.warehouse,
  ),
];

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
  final _signalR = SignalRService();

  Map<String, Map<String, dynamic>> _stationStatus = {};

  @override
  void initState() {
    super.initState();
    _signalR.addStationDispatchedListener(_handleStationDispatched);
    _signalR.addPalletArrivedListener(_handlePalletArrived);
    _signalR.addPalletReturnedListener(_handlePalletReturned);
    _signalR.addLabelingCompletedListener(_handleLabelingCompleted);
    _initSignalR();
    _loadStationStatus();
  }

  @override
  void dispose() {
    _signalR.removeStationDispatchedListener(_handleStationDispatched);
    _signalR.removePalletArrivedListener(_handlePalletArrived);
    _signalR.removePalletReturnedListener(_handlePalletReturned);
    _signalR.removeLabelingCompletedListener(_handleLabelingCompleted);
    _signalR.disconnect();
    _stationController.dispose();
    super.dispose();
  }

  Future<void> _initSignalR() async {
    await _signalR.connect();
  }

  Future<void> _loadStationStatus() async {
    final result = await _api.getStationStatus();
    if (!mounted || !result.success) return;

    final map = <String, Map<String, dynamic>>{};
    for (final station in result.data!) {
      map[station['stationId'] as String] = station;
    }
    setState(() => _stationStatus = map);
  }

  void _handleStationDispatched(Map<String, dynamic> data) {
    final stationId = data['stationId'] as String?;
    if (stationId == null || !_kStations.any((station) => station.id == stationId)) {
      return;
    }

    if (mounted) {
      setState(() {
        _stationStatus = {
          ..._stationStatus,
          stationId: {
            ...?_stationStatus[stationId],
            'stationId': stationId,
            'palletId': data['palletId'],
            'destination': data['destination'],
            'items': _stationStatus[stationId]?['items'] ?? const [],
          },
        };
      });
    }

    _loadStationStatus();
  }

  void _handlePalletArrived(Map<String, dynamic> data) {
    _loadStationStatus();
  }

  void _handlePalletReturned(Map<String, dynamic> data) {
    _loadStationStatus();
  }

  void _handleLabelingCompleted(Map<String, dynamic> data) {
    _loadStationStatus();
  }

  void _onStationBarcodeScan() {
    final raw = _stationController.text.trim().toUpperCase();
    _stationController.clear();
    if (raw.isEmpty) return;

    final station = _kStations.where((item) => item.id == raw).firstOrNull;
    if (station == null) {
      showErrorDialog(
        context,
        message: 'Station not found: $raw\nSupported stations: STN-1, STN-2, STN-3',
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
        title: 'Putaway - Store Items',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PutawayStationScanCard(
                controller: _stationController,
                onSubmit: _onStationBarcodeScan,
              ),
              const SizedBox(height: 20),
              PutawayStationGrid(
                stations: _kStations,
                stationStatus: _stationStatus,
                onStationTap: _openStationPopup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
