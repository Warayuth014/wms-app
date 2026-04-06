import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../services/api_service.dart';
import '../../../services/signalr_service.dart';
import '../../../widgets/common_widgets.dart';
import '../shared/putaway_shared_widgets.dart';
import 'widgets/prework_receive_column.dart';
import 'widgets/prework_receive_sheet.dart';
import 'widgets/prework_send_column.dart';
import 'widgets/prework_station_scan_card.dart';

const _kColorReceive = Color(0xFF00796B);
const _kColorSend = Color(0xFFD84315);

final _kPWStations = [
  StationInfo(
    id: 'PW-STN-1',
    label: 'Receive Pallet',
    color: _kColorReceive,
    icon: MdiIcons.trayArrowDown,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-2',
    label: 'Send Pallet',
    color: _kColorSend,
    icon: MdiIcons.trayArrowUp,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  StationInfo(
    id: 'PW-STN-3',
    label: 'Receive Pallet',
    color: _kColorReceive,
    icon: MdiIcons.trayArrowDown,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-4',
    label: 'Send Pallet',
    color: _kColorSend,
    icon: MdiIcons.trayArrowUp,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  StationInfo(
    id: 'PW-STN-5',
    label: 'Receive Pallet',
    color: _kColorReceive,
    icon: MdiIcons.trayArrowDown,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-6',
    label: 'Send Pallet',
    color: _kColorSend,
    icon: MdiIcons.trayArrowUp,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
];

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
  final _signalR = SignalRService();

  Map<String, Map<String, dynamic>> _stationStatus = {};
  Map<String, Map<String, dynamic>> _receiveStatus = {};

  Timer? _returnAnimMidTimer;
  Timer? _returnAnimEndTimer;

  String? _returnAnimStation;
  String _returnAnimText = '';

  @override
  void initState() {
    super.initState();
    _signalR.addStationDispatchedListener(_handleStationDispatched);
    _signalR.addPalletArrivedListener(_handlePalletArrived);
    _signalR.addPalletReturnedListener(_handlePalletReturned);
    _signalR.addLabelingCompletedListener(_handleLabelingCompleted);
    _initSignalR();
    _loadAllStatus();
  }

  @override
  void dispose() {
    _cancelReturnAnimation();
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

  Future<void> _loadAllStatus() async {
    await Future.wait([_loadStationStatus(), _loadPreworkStationStatus()]);
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

  Future<void> _loadPreworkStationStatus() async {
    final result = await _api.getPreworkStationStatus();
    if (!mounted || !result.success) return;

    final map = <String, Map<String, dynamic>>{};
    for (final station in result.data!) {
      map[station['stationId'] as String] = station;
    }
    setState(() => _receiveStatus = map);
  }

  void _onStationBarcodeScan() {
    final raw = _stationController.text.trim().toUpperCase();
    _stationController.clear();
    if (raw.isEmpty) return;

    final station = _kPWStations.where((item) => item.id == raw).firstOrNull;
    if (station == null) {
      showErrorDialog(
        context,
        message: 'Station not found: $raw\nSupported stations: PW-STN-1 to PW-STN-6',
      );
      return;
    }

    _openStationPopup(station);
  }

  void _playReturnAnimation(String stationId) {
    _cancelReturnAnimation();
    setState(() {
      _returnAnimStation = stationId;
      _returnAnimText = 'AMR is picking up the pallet...';
    });

    _returnAnimMidTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _returnAnimStation != stationId) return;

      setState(() => _returnAnimText = 'AMR is returning the pallet...');

      _returnAnimEndTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || _returnAnimStation != stationId) return;

        setState(() {
          _returnAnimStation = null;
          _returnAnimText = '';
        });
        _loadAllStatus();
      });
    });
  }

  void _cancelReturnAnimation() {
    _returnAnimMidTimer?.cancel();
    _returnAnimEndTimer?.cancel();
    _returnAnimMidTimer = null;
    _returnAnimEndTimer = null;
  }

  void _handleStationDispatched(Map<String, dynamic> data) {
    final stationId = data['stationId'] as String?;
    final destination = data['destination'] as String?;

    if (stationId != null &&
        _kPWStations.any((station) => station.id == stationId && station.pwRole == PWRole.send) &&
        mounted) {
      setState(() {
        _stationStatus = {
          ..._stationStatus,
          stationId: {
            ...?_stationStatus[stationId],
            'stationId': stationId,
            'palletId': data['palletId'],
            'destination': destination,
            'items': _stationStatus[stationId]?['items'] ?? const [],
          },
        };
      });
    }

    if (destination == 'PREWORK') {
      _loadPreworkStationStatus();
    }
    _loadStationStatus();
  }

  void _handlePalletArrived(Map<String, dynamic> data) {
    _loadAllStatus();
  }

  void _handlePalletReturned(Map<String, dynamic> data) {
    final stationId = data['stationId'] as String?;
    if (stationId != null &&
        _kPWStations.any((station) => station.id == stationId && station.pwRole == PWRole.receive)) {
      _playReturnAnimation(stationId);
      return;
    }

    _loadAllStatus();
  }

  void _handleLabelingCompleted(Map<String, dynamic> data) {
    _loadAllStatus();
  }

  void _openStationPopup(StationInfo station) {
    if (_returnAnimStation == station.id) return;

    if (station.pwRole == PWRole.receive) {
      final info = _receiveStatus[station.id];
      final palletId = info?['palletId'] as String?;
      final palletStatus = info?['palletStatus'] as String?;

      if (palletStatus == 'IN_TRANSIT') return;

      final cutItems =
          (info?['cutItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PreworkReceiveSheet(
          station: station,
          userId: widget.userId,
          palletId: palletId,
          palletStatus: palletStatus,
          cutItems: cutItems,
          onCompleted: () => _playReturnAnimation(station.id),
        ),
      );
      return;
    }

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
          _loadAllStatus();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiveStations =
        _kPWStations.where((station) => station.pwRole == PWRole.receive).toList();
    final sendStations =
        _kPWStations.where((station) => station.pwRole == PWRole.send).toList();

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
              PreworkStationScanCard(
                controller: _stationController,
                onSubmit: _onStationBarcodeScan,
                accentColor: _kColorReceive,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PreworkReceiveColumn(
                      stations: receiveStations,
                      color: _kColorReceive,
                      returnAnimStation: _returnAnimStation,
                      returnAnimText: _returnAnimText,
                      receiveStatus: _receiveStatus,
                      onStationTap: _openStationPopup,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PreworkSendColumn(
                      stations: sendStations,
                      color: _kColorSend,
                      stationStatus: _stationStatus,
                      onStationTap: _openStationPopup,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
