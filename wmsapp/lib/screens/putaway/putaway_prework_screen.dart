// lib/screens/putaway/putaway_prework_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/signalr_service.dart';
import 'putaway_widgets.dart';

// ── Station constants (PW-STN only) ──────────
const _kColorReceive = Color(0xFF00796B); // teal เข้ม — รับ pallet
const _kColorSend = Color(0xFFD84315); // ส้มแดง — ส่ง pallet

final _kPWStations = [
  StationInfo(
    id: 'PW-STN-1',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: MdiIcons.trayArrowDown,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-2',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: MdiIcons.trayArrowUp,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  StationInfo(
    id: 'PW-STN-3',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: MdiIcons.trayArrowDown,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-4',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: MdiIcons.trayArrowUp,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  StationInfo(
    id: 'PW-STN-5',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: MdiIcons.trayArrowDown,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  StationInfo(
    id: 'PW-STN-6',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: MdiIcons.trayArrowUp,
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
  final _signalR = SignalRService();

  // stationId → { palletId, destination, items } (สำหรับฝั่งส่ง)
  Map<String, Map<String, dynamic>> _stationStatus = {};

  // stationId → { palletId, palletStatus, cutItems } (สำหรับฝั่งรับ)
  Map<String, Map<String, dynamic>> _receiveStatus = {};
  Timer? _returnAnimMidTimer;
  Timer? _returnAnimEndTimer;

  // Return animation state
  String? _returnAnimStation;  // station ที่กำลังแสดง animation
  String _returnAnimText = ''; // ข้อความแสดง

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
    if (!mounted) return;
    if (result.success) {
      final map = <String, Map<String, dynamic>>{};
      for (final s in result.data!) {
        map[s['stationId'] as String] = s;
      }
      setState(() => _stationStatus = map);
    }
  }

  Future<void> _loadPreworkStationStatus() async {
    final result = await _api.getPreworkStationStatus();
    if (!mounted) return;
    if (result.success) {
      final map = <String, Map<String, dynamic>>{};
      for (final s in result.data!) {
        map[s['stationId'] as String] = s;
      }
      setState(() => _receiveStatus = map);
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

  void _playReturnAnimation(String stationId) {
    _cancelReturnAnimation();
    setState(() {
      _returnAnimStation = stationId;
      _returnAnimText = 'AMR กำลังมารับ Pallet...';
    });
    _returnAnimMidTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _returnAnimStation != stationId) return;
      setState(() => _returnAnimText = 'AMR กำลังคืน Pallet...');
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
        _kPWStations.any((s) => s.id == stationId && s.pwRole == PWRole.send) &&
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
        _kPWStations.any((s) => s.id == stationId && s.pwRole == PWRole.receive)) {
      _playReturnAnimation(stationId);
      return;
    }

    _loadAllStatus();
  }

  void _handleLabelingCompleted(Map<String, dynamic> data) {
    _loadAllStatus();
  }

  void _openStationPopup(StationInfo station) {
    // กำลังแสดง return animation → ไม่ต้องเปิด popup
    if (_returnAnimStation == station.id) return;

    // ฝั่งรับ → popup แสดง cut items + ปุ่มคืน pallet
    if (station.pwRole == PWRole.receive) {
      final info = _receiveStatus[station.id];
      final palletId = info?['palletId'] as String?;
      final palletStatus = info?['palletStatus'] as String?;

      // AMR กำลังนำ Pallet มา → ไม่ต้องเปิด popup
      if (palletStatus == 'IN_TRANSIT') return;

      final cutItems =
          (info?['cutItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PreworkReceiveSheet(
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

    // ฝั่งส่ง → AMR กำลังมารับ → ไม่ต้องเปิด popup
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
                    Row(
                      children: [
                        Icon(
                          MdiIcons.barcodeScan,
                          color: _kColorReceive,
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
                          icon: MdiIcons.trayArrowDown,
                          color: _kColorReceive,
                        ),
                        const SizedBox(height: 10),
                        for (final s in receiveStations) ...[
                          _buildReceiveStationCard(s),
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
                          icon: MdiIcons.trayArrowUp,
                          color: _kColorSend,
                        ),
                        const SizedBox(height: 10),
                        for (final s in sendStations) ...[
                          StationCard(
                            station: s,
                            isDispatching: _stationStatus.containsKey(s.id),
                            busyPalletId:
                                _stationStatus[s.id]?['palletId'] as String?,
                            busyDestination:
                                _stationStatus[s.id]?['destination'] as String?,
                            onTap: () => _openStationPopup(s),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
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

  Widget _buildReceiveStationCard(StationInfo station) {
    final isReturning = _returnAnimStation == station.id;

    if (isReturning) {
      return StationCard(
        station: station,
        isDispatching: true,
        busyPalletId: '',
        busyDestination: _returnAnimText,
        onTap: () {},
      );
    }

    final info = _receiveStatus[station.id];
    final palletId = info?['palletId'] as String?;
    final palletStatus = info?['palletStatus'] as String?;
    final isInTransit = palletStatus == 'IN_TRANSIT';
    final hasPallet = palletId != null;

    return StationCard(
      station: station,
      isDispatching: isInTransit,
      busyPalletId: palletId,
      busyDestination: isInTransit
          ? 'กำลังมาส่ง...'
          : hasPallet
          ? 'ตัดยอดแล้ว'
          : null,
      onTap: () => _openStationPopup(station),
    );
  }
}

// =============================================
// _PreworkReceiveSheet — popup แสดง cut items + ปุ่มคืน pallet
// =============================================
class _PreworkReceiveSheet extends StatefulWidget {
  final StationInfo station;
  final String userId;
  final String? palletId;
  final String? palletStatus;
  final List<Map<String, dynamic>> cutItems;
  final VoidCallback onCompleted;

  const _PreworkReceiveSheet({
    required this.station,
    required this.userId,
    this.palletId,
    this.palletStatus,
    required this.cutItems,
    required this.onCompleted,
  });

  @override
  State<_PreworkReceiveSheet> createState() => _PreworkReceiveSheetState();
}

class _PreworkReceiveSheetState extends State<_PreworkReceiveSheet> {
  final _api = ApiService();
  bool _loading = false;

  Future<void> _returnPallet() async {
    if (widget.palletId == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'คืน Pallet เปล่า',
      message:
          'คืน ${widget.palletId}\n'
          'Pallet จะถูกเปลี่ยนเป็นสถานะ AVAILABLE\n\n'
          'ยืนยันคืน Pallet?',
      confirmLabel: 'คืน Pallet',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await _api.preworkReturnPallet(
      palletId: widget.palletId!,
      stationId: widget.station.id,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    Navigator.pop(context);
    showSuccessSnackbar(context, '${widget.palletId} คืนแล้ว (AVAILABLE)');
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final hasPallet = widget.palletId != null;
    final isInTransit = widget.palletStatus == 'IN_TRANSIT';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: LoadingOverlay(
        loading: _loading,
        message: 'กำลังคืน Pallet...',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Station Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.station.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(widget.station.icon, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.station.id,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          hasPallet ? widget.palletId! : 'ว่าง — รอ Pallet',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (hasPallet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.palletStatus ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!hasPallet) ...[
              // Empty state
              Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPad + 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(MdiIcons.packageVariant, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'ไม่มี Pallet ที่จุดนี้',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ส่ง Pallet PW มาจาก Putaway ก่อน',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isInTransit) ...[
              // ── IN_TRANSIT: Pallet กำลังมา ──
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        MdiIcons.truckDeliveryOutline,
                        color: AppTheme.warning,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.palletId!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AMR กำลังนำ Pallet มาส่ง...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'รอยิง API simulate/asrs/receive-pallet\nเพื่อจำลอง Pallet ถึงจุด Prework',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ── ตัดยอดแล้ว — Pallet เปล่า ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'ตัดยอดแล้ว — Pallet เปล่า',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Return pallet button
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _returnPallet,
                    icon: Icon(MdiIcons.undoVariant, color: Colors.white),
                    label: const Text(
                      'คืน Pallet เปล่า',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
