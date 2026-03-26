// lib/screens/putaway/putaway_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

// ── Station definition ───────────────────────
enum PWRole { none, receive, send }

class _StationInfo {
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  // null = รับทุก type, 'PW' = รับแค่ PW, 'FG' = รับแค่ FG
  final String? allowedType;
  // null = ให้ user เลือก destination, non-null = ตายตัวไม่มี selector
  final String? fixedDestination;
  // PW role: receive = เรียก pallet จาก ASRS, send = convert & ส่งเข้า ASRS
  final PWRole pwRole;

  const _StationInfo({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
    this.allowedType,
    this.fixedDestination,
    this.pwRole = PWRole.none,
  });
}

const _kStations = [
  _StationInfo(
    id: 'STN-1',
    label: 'Station 1',
    color: AppTheme.primary,
    icon: Icons.warehouse,
  ),
  _StationInfo(
    id: 'STN-2',
    label: 'Station 2',
    color: AppTheme.teal,
    icon: Icons.warehouse,
  ),
  _StationInfo(
    id: 'STN-3',
    label: 'Station 3',
    color: AppTheme.success,
    icon: Icons.warehouse,
  ),
];

// สีรับ = เขียว teal, สีส่ง = ส้มแดง — แยกชัดเจน
const _kColorReceive = Color(0xFF00796B); // teal เข้ม
const _kColorSend = Color(0xFFD84315); // ส้มแดง

const _kPWStations = [
  // คี่ = รับ pallet จาก ASRS (recall)
  _StationInfo(
    id: 'PW-STN-1',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: Icons.download,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  // คู่ = ส่ง pallet เข้า ASRS (convert & putaway)
  _StationInfo(
    id: 'PW-STN-2',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: Icons.upload,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  _StationInfo(
    id: 'PW-STN-3',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: Icons.download,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  _StationInfo(
    id: 'PW-STN-4',
    label: 'ส่ง Pallet',
    color: _kColorSend,
    icon: Icons.upload,
    allowedType: 'PW',
    fixedDestination: 'ASRS',
    pwRole: PWRole.send,
  ),
  _StationInfo(
    id: 'PW-STN-5',
    label: 'รับ Pallet',
    color: _kColorReceive,
    icon: Icons.download,
    allowedType: 'PW',
    pwRole: PWRole.receive,
  ),
  _StationInfo(
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
// PutawayScreen
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

class _PutawayScreenState extends State<PutawayScreen>
    with SingleTickerProviderStateMixin {
  final _stationController = TextEditingController();
  late final TabController _tabCtrl;

  // stations ที่กำลัง dispatch อยู่ → แสดง arrow animation
  final Set<String> _dispatchingStations = {};
  final Map<String, Timer> _dispatchTimers = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _stationController.dispose();
    _tabCtrl.dispose();
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

    final station = [
      ..._kStations,
      ..._kPWStations,
    ].where((s) => s.id == raw).firstOrNull;
    if (station == null) {
      showErrorDialog(
        context,
        message:
            'ไม่พบ Station: $raw\n'
            'STN: STN-1, STN-2, STN-3\n'
            'Prework: PW-STN-1 ~ PW-STN-6',
      );
      return;
    }

    // สลับ tab ให้ตรงกับ station ที่สแกน
    if (raw.startsWith('PW-')) {
      _tabCtrl.animateTo(1);
    } else {
      _tabCtrl.animateTo(0);
    }

    _openStationPopup(station);
  }

  Widget _buildStationRow(List<_StationInfo> stations) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < stations.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _StationCard(
              station: stations[i],
              isDispatching: _dispatchingStations.contains(stations[i].id),
              onTap: () => _openStationPopup(stations[i]),
            ),
          ),
        ],
      ],
    );
  }

  void _openStationPopup(_StationInfo station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationSheet(
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
        title: 'Putaway — เก็บ pallet เข้า ASRS',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Scan station barcode ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: WmsCard(
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
                      hint: 'เช่น STN-1, PW-STN-1',
                      controller: _stationController,
                      onSubmit: _onStationBarcodeScan,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab bar ─────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textPrimary(context),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'Sarabun',
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'Sarabun',
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warehouse, size: 18),
                        SizedBox(width: 6),
                        Text('Station'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_circle, size: 18),
                        SizedBox(width: 6),
                        Text('Prework'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tab content ─────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 1: Station ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เลือก Station (FG & PW)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'สแกน Pallet → เลือก ASRS หรือ Prework',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStationRow(_kStations),
                      ],
                    ),
                  ),

                  // ── Tab 2: Prework ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Legend ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kColorReceive.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.download,
                                    size: 14,
                                    color: _kColorReceive,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'รับ — เรียก Pallet จาก ASRS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _kColorReceive,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kColorSend.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.upload,
                                    size: 14,
                                    color: _kColorSend,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'ส่ง — Convert & ส่ง ASRS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _kColorSend,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2 columns: left = รับ (receive), right = ส่ง (send)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Left column: รับ Pallet ──
                            Expanded(
                              child: Column(
                                children: [
                                  for (final s in _kPWStations.where(
                                    (s) => s.pwRole == PWRole.receive,
                                  )) ...[
                                    _StationCard(
                                      station: s,
                                      isDispatching: _dispatchingStations
                                          .contains(s.id),
                                      onTap: () => _openStationPopup(s),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // ── Right column: ส่ง Pallet ──
                            Expanded(
                              child: Column(
                                children: [
                                  for (final s in _kPWStations.where(
                                    (s) => s.pwRole == PWRole.send,
                                  )) ...[
                                    _StationCard(
                                      station: s,
                                      isDispatching: _dispatchingStations
                                          .contains(s.id),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// _StationCard  (StatefulWidget — มี animation)
// =============================================
class _StationCard extends StatefulWidget {
  final _StationInfo station;
  final VoidCallback onTap;
  final bool isDispatching;

  const _StationCard({
    required this.station,
    required this.onTap,
    this.isDispatching = false,
  });

  @override
  State<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<_StationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isDispatching) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_StationCard old) {
    super.didUpdateWidget(old);
    if (widget.isDispatching && !old.isDispatching) {
      _ctrl.repeat();
    } else if (!widget.isDispatching && old.isDispatching) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isDispatching ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: widget.isDispatching
              ? AppTheme
                    .danger // แดง
              : widget.station.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (widget.isDispatching
                          ? AppTheme.danger
                          : widget.station.color)
                      .withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.isDispatching
            ? _buildDispatchingContent()
            : _buildNormalContent(),
      ),
    );
  }

  // ── Arrow animation content ───────────────
  Widget _buildDispatchingContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // วงกลมไอคอน
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white70, size: 28),
        ),
        const SizedBox(height: 10),

        // ลูกศรอนิเมชั่น 3 ตัว
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _arrow(phase: 0.0),
                const SizedBox(width: 2),
                _arrow(phase: 0.33),
                const SizedBox(width: 2),
                _arrow(phase: 0.66),
              ],
            );
          },
        ),
        const SizedBox(height: 8),

        Text(
          widget.station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          widget.station.pwRole == PWRole.receive
              ? 'AGV กำลังนำ Pallet มา...'
              : 'AGV กำลังมารับ...',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _arrow({required double phase}) {
    // opacity: triangle wave offset by phase
    double t = (_ctrl.value - phase) % 1.0;
    double opacity = t < 0.5 ? t * 2 : (1.0 - t) * 2;
    opacity = opacity.clamp(0.15, 1.0);
    return Opacity(
      opacity: opacity,
      child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 22),
    );
  }

  // ── Normal station card content ───────────
  Widget _buildNormalContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.station.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_agvWheel(), const SizedBox(width: 8), _agvWheel()],
        ),
        const SizedBox(height: 8),
        Text(
          widget.station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          widget.station.label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: Colors.white, size: 11),
              SizedBox(width: 3),
              Text(
                'กดเลือก',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _agvWheel() => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}

// =============================================
// _StationSheet  (bottom sheet popup)
// =============================================
class _StationSheet extends StatefulWidget {
  final _StationInfo station;
  final String userId;
  final VoidCallback onConfirmed; // callback หลัง confirm สำเร็จ

  const _StationSheet({
    required this.station,
    required this.userId,
    required this.onConfirmed,
  });

  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  final _palletController = TextEditingController();
  final _api = ApiService();

  PutawayPalletInfo? _pallet;
  bool _loadingPallet = false;
  bool _loadingConfirm = false;

  String _selectedDestination = 'ASRS';

  @override
  void dispose() {
    _palletController.dispose();
    super.dispose();
  }

  bool get _isReceive => widget.station.pwRole == PWRole.receive;

  Future<void> _scanPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      return;
    }

    // ── Receive station → recall จาก ASRS ทันที ──
    if (_isReceive) {
      await _recallPallet(palletId);
      return;
    }

    // ── Send station / Normal station → scan pallet ──
    setState(() {
      _loadingPallet = true;
      _pallet = null;
    });

    final result = await _api.scanPalletForPutaway(
      palletId,
      stationId: widget.station.id,
    );
    setState(() => _loadingPallet = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    final pallet = result.data!;

    // ตรวจว่า station นี้รับประเภทนี้ได้ไหม
    if (widget.station.allowedType != null &&
        pallet.type != widget.station.allowedType) {
      showErrorDialog(
        context,
        message:
            '${widget.station.id} รับเฉพาะ Pallet ประเภท '
            '${widget.station.allowedType}\n'
            'Pallet นี้เป็นประเภท ${pallet.type}',
      );
      return;
    }

    setState(() {
      _pallet = pallet;
      _selectedDestination =
          widget.station.fixedDestination ?? pallet.suggestedDestination;
    });
  }

  // ── Receive: เรียก PW Pallet จาก ASRS มาที่ station นี้ ──
  Future<void> _recallPallet(String palletId) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'เรียก Pallet จาก ASRS',
      message:
          'เรียก $palletId จาก ASRS\n'
          'มาที่ ${widget.station.id}\n\n'
          'AGV จะนำ Pallet มาส่งทันที',
      confirmLabel: 'เรียก Pallet',
    );
    if (!confirm || !mounted) return;

    setState(() => _loadingConfirm = true);

    final result = await _api.recallToPrework(
      palletId: palletId,
      stationId: widget.station.id,
      operatorId: widget.userId,
    );

    setState(() => _loadingConfirm = false);
    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    Navigator.pop(context);
    widget.onConfirmed();
  }

  // ── Send / Normal: confirm putaway ──
  Future<void> _confirmPutaway({bool convertToFG = true}) async {
    if (_pallet == null) return;

    final destLabel = _selectedDestination == 'ASRS' ? 'ASRS' : 'Prework';
    final isConvert = widget.station.fixedDestination != null && convertToFG;
    final isSendAsrsAsPW =
        widget.station.fixedDestination != null && !convertToFG;

    String title;
    String message;
    if (isConvert) {
      title = 'ยืนยัน Convert & Putaway';
      message =
          'เปลี่ยน ${_pallet!.palletId} (PW → FG)\n'
          'แล้วส่งเข้า ASRS\n\n'
          'โฟล์คลิฟไร้คนขับจะมารับทันที';
    } else if (isSendAsrsAsPW) {
      title = 'ยืนยันส่งไป ASRS (ยังเป็น PW)';
      message =
          'ส่ง ${_pallet!.palletId} ไปเก็บที่ ASRS\n'
          'โดยยังคงสถานะเป็น PW (ไม่ convert)\n\n'
          'โฟล์คลิฟไร้คนขับจะมารับทันที';
    } else {
      title = 'ยืนยัน Putaway';
      message =
          'เก็บ Pallet ${_pallet!.palletId}\n'
          'ที่ ${widget.station.id} → $destLabel\n\n'
          'โฟล์คลิฟไร้คนขับจะมารับทันที';
    }

    final confirm = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'ยืนยัน',
    );
    if (!confirm) return;

    setState(() => _loadingConfirm = true);

    final result = await _api.confirmPutaway(
      stationId: widget.station.id,
      palletId: _pallet!.palletId,
      destination: _selectedDestination,
      operatorId: widget.userId,
      convertToFG: convertToFG,
    );

    setState(() => _loadingConfirm = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    Navigator.pop(context);
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.viewPadding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: LoadingOverlay(
        loading: _loadingConfirm,
        message: 'กำลังสั่ง Putaway...',
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ─────────────────────────
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

              // ── Station Header ──────────────────
              Container(
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
                          widget.station.label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.smart_toy,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'AGV Ready',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Scan Pallet ─────────────────────
              Text(
                _isReceive ? 'เรียก Pallet จาก ASRS' : 'สแกน Pallet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isReceive) ...[
                const SizedBox(height: 4),
                Text(
                  'ใส่ Pallet ID (PW) ที่ต้องการเรียกจาก ASRS',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ScanTextField(
                label: 'Pallet ID',
                hint: 'เช่น PAL-001',
                controller: _palletController,
                onSubmit: _scanPallet,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _isReceive ? 'เรียก Pallet' : 'ค้นหา Pallet',
                icon: _isReceive ? Icons.download : Icons.search,
                loading: _isReceive ? _loadingConfirm : _loadingPallet,
                onPressed: _scanPallet,
              ),

              // ── Pallet Info (เฉพาะ Send / Normal) ──
              if (!_isReceive && _pallet != null) ...[
                const SizedBox(height: 16),
                _buildPalletInfo(),

                // แสดง selector เฉพาะ station ที่ไม่มี fixedDestination
                if (widget.station.fixedDestination == null) ...[
                  const SizedBox(height: 16),
                  _buildDestinationSelector(),
                ],

                const SizedBox(height: 16),
                PrimaryButton(
                  label: widget.station.fixedDestination != null
                      ? 'Convert PW→FG & ส่ง ASRS'
                      : 'เก็บ Pallet',
                  icon: widget.station.fixedDestination != null
                      ? Icons.swap_horiz
                      : Icons.inventory_2,
                  onPressed: _confirmPutaway,
                ),

                if (widget.station.fixedDestination != null) ...[
                  const SizedBox(height: 10),
                  WarningButton(
                    label: 'ส่งไป ASRS (ยังเป็น PW)',
                    icon: Icons.warehouse,
                    onPressed: () => _confirmPutaway(convertToFG: false),
                  ),
                ],
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPalletInfo() {
    final isFG = _pallet!.type == 'FG';
    final typeColor = isFG ? AppTheme.success : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _pallet!.palletId,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _pallet!.type,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(label: 'สถานะ', value: _pallet!.status),
          InfoRow(
            label: 'ปลายทาง',
            value: widget.station.fixedDestination != null
                ? 'ASRS (convert PW→FG)'
                : 'เลือกด้านล่าง',
          ),
          InfoRow(label: 'สินค้า', value: '${_pallet!.items.length} รายการ'),
          if (_pallet!.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _pallet!.message,
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationSelector() {
    final isPW = _pallet!.type == 'PW';
    final headerColor = isPW ? AppTheme.warning : AppTheme.primary;
    final headerIcon = isPW ? Icons.warning_amber : Icons.inventory_2;
    final headerText = isPW
        ? 'Pallet ประเภท PW — เลือกปลายทาง'
        : 'Pallet ประเภท FG — เลือกปลายทาง';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, color: headerColor, size: 18),
              const SizedBox(width: 6),
              Text(
                headerText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DestButton(
                  label: 'ASRS',
                  subtitle: 'เก็บเข้าคลังหลัก',
                  icon: Icons.domain,
                  selected: _selectedDestination == 'ASRS',
                  onTap: () => setState(() => _selectedDestination = 'ASRS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DestButton(
                  label: 'Prework',
                  subtitle: 'ส่งจุด Prework',
                  icon: Icons.build_circle,
                  selected: _selectedDestination == 'PREWORK',
                  onTap: () => setState(() => _selectedDestination = 'PREWORK'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Destination choice button ─────────────────
class _DestButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DestButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppTheme.textGrey(context),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: selected ? Colors.white70 : AppTheme.textGrey(context),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
