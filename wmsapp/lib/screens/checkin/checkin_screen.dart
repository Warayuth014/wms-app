import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

enum _CheckInState { scan, slotDetail, trackingReady, dispatchDone }

class CheckInScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const CheckInScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  _CheckInState _state = _CheckInState.scan;
  bool _loading = false;

  // data
  List<CheckInSlotSummary> _activeSlots = [];
  CheckInSlotDetail? _slotDetail;
  CompleteCheckInResponse? _completeResult;
  DispatchCheckInResponse? _dispatchResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveSlots();
      _scanFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────

  Future<void> _loadActiveSlots() async {
    final res = await _api.getActiveCheckInSlots();
    if (!mounted) return;
    if (res.success) {
      setState(() => _activeSlots = res.data ?? []);
    }
  }

  Future<void> _scanCarton() async {
    final packingId = _scanCtrl.text.trim().toUpperCase();
    if (packingId.isEmpty) return;

    setState(() => _loading = true);
    final res = await _api.scanCheckIn(
      packingId: packingId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'สแกนไม่สำเร็จ');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    final r = res.data!;
    _scanCtrl.clear();

    // เด้งข้อความให้เห็นชัด ๆ ว่าวางช่องไหน
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(r.message)),
            ],
          ),
          backgroundColor: r.isReadyToComplete
              ? AppTheme.success
              : AppTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // เปิดหน้า slot detail
    await _openSlot(r.slotId);
  }

  Future<void> _openSlot(String slotId) async {
    setState(() => _loading = true);
    final res = await _api.getCheckInSlot(slotId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'โหลด Slot ไม่สำเร็จ');
      return;
    }

    setState(() {
      _slotDetail = res.data;
      _state = _CheckInState.slotDetail;
    });
  }

  Future<void> _completeSlot() async {
    final slot = _slotDetail;
    if (slot == null) return;

    setState(() => _loading = true);
    final res = await _api.completeCheckIn(
      slotId: slot.slotId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Complete ไม่สำเร็จ');
      return;
    }

    setState(() {
      _completeResult = res.data;
      _state = _CheckInState.trackingReady;
    });
  }

  Future<void> _dispatchSlot() async {
    final slot = _completeResult?.slotId ?? _slotDetail?.slotId;
    if (slot == null) return;

    setState(() => _loading = true);
    final res = await _api.dispatchCheckIn(
      slotId: slot,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Dispatch ไม่สำเร็จ');
      return;
    }

    setState(() {
      _dispatchResult = res.data;
      _state = _CheckInState.dispatchDone;
    });
  }

  void _backToScan() {
    setState(() {
      _slotDetail = null;
      _completeResult = null;
      _dispatchResult = null;
      _state = _CheckInState.scan;
    });
    _loadActiveSlots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _CheckInState.scan,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backToScan();
      },
      child: Scaffold(
        appBar: WmsAppBar(title: 'Check-in', userName: widget.fullName),
        body: SafeArea(
          top: false,
          child: LoadingOverlay(
            loading: _loading,
            message: 'กำลังประมวลผล...',
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_state == _CheckInState.scan) _buildScan(),
                  if (_state == _CheckInState.slotDetail) _buildSlotDetail(),
                  if (_state == _CheckInState.trackingReady)
                    _buildTrackingReady(),
                  if (_state == _CheckInState.dispatchDone)
                    _buildDispatchDone(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── State 1: Scan Carton + list active slots ────────────
  Widget _buildScan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.packageVariantClosed,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'สแกน Carton',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'สแกน Packing ID ที่ติดบน Carton',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scanCtrl,
                  focusNode: _scanFocus,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Packing ID',
                    prefixIcon: Icon(MdiIcons.barcodeScan),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _scanCarton(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _scanCarton,
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text('สแกน'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Active slots ──
        SectionHeader(
          title: 'ช่องที่เปิดอยู่ (${_activeSlots.length})',
          icon: MdiIcons.viewGridOutline,
        ),
        const SizedBox(height: 8),
        if (_activeSlots.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(MdiIcons.trayRemove,
                        color: Colors.grey[400], size: 40),
                    const SizedBox(height: 8),
                    Text('ยังไม่มีช่อง check-in',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          )
        else
          ..._activeSlots.map((s) => _buildSlotCard(s)),
      ],
    );
  }

  Widget _buildSlotCard(CheckInSlotSummary s) {
    final ready = s.isReady;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ready ? AppTheme.success : AppTheme.warning,
          child: Icon(
            ready ? Icons.check : MdiIcons.viewGridOutline,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          s.slotId,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.owner, style: const TextStyle(fontSize: 13)),
            Text(
              'กล่อง: ${s.cartonsInSlot}/${s.expectedCartons}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusChip(s.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openSlot(s.slotId),
      ),
    );
  }

  // ── State 2: Slot detail ──────────────────────────────────
  Widget _buildSlotDetail() {
    final slot = _slotDetail!;
    final total = slot.expectedCartons;
    final current = slot.cartonsInSlot;
    final pct = total > 0 ? current / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.viewGridOutline,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      slot.slotId,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _statusChip(slot.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('ลูกค้า: ${slot.owner}',
                    style:
                        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                // progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$current / $total กล่อง',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation(
                        pct >= 1.0 ? AppTheme.success : AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── scan field (ถ้ายังไม่ READY) ──
        if (slot.status == 'OPEN')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _scanCtrl,
                focusNode: _scanFocus,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'สแกน Carton เพิ่ม',
                  prefixIcon: Icon(MdiIcons.barcodeScan),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _scanCarton(),
              ),
            ),
          ),
        const SizedBox(height: 8),

        // ── Carton list ──
        ...slot.cartons.map((c) => Card(
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.success.withValues(alpha: 0.15),
                  child: const Icon(Icons.check,
                      color: AppTheme.success, size: 16),
                ),
                title: Text(c.packingId,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Pallet: ${c.palletId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                trailing: Text(
                  _formatTime(c.scannedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            )),
        const SizedBox(height: 12),

        // ── Complete button (เมื่อครบ) ──
        if (slot.status == 'OPEN' && slot.isReadyToComplete)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _completeSlot,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('ยืนยันครบ — ปริ้น Tracking',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

        // ── ถ้า READY แล้ว → แสดงปุ่ม dispatch ──
        if (slot.status == 'READY') ...[
          if (slot.trackingId != null)
            Card(
              color: AppTheme.secondary.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.barcodeScan,
                            color: AppTheme.secondary, size: 18),
                        const SizedBox(width: 6),
                        const Text('Tracking ID',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(slot.trackingId!,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กำลังปริ้น Tracking...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.print, size: 20),
              label: const Text('Print Tracking + ใบส่งของ',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _dispatchSlot,
              icon: Icon(MdiIcons.truckDeliveryOutline, size: 20),
              label: const Text('ย้ายขึ้นรถแล้ว',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _backToScan,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('กลับ'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textGrey(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── State 3: Tracking ready (just completed) ──────────────
  Widget _buildTrackingReady() {
    final r = _completeResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.check_circle,
                    color: AppTheme.success, size: 56),
                const SizedBox(height: 12),
                Text(
                  'ของลูกค้า ${r.owner}\nพร้อมจัดส่ง',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text('ช่อง ${r.slotId} • ${r.cartonsCount} กล่อง',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.secondary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(MdiIcons.barcodeScan,
                    color: AppTheme.secondary, size: 28),
                const SizedBox(height: 6),
                const Text('Tracking ID',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(r.trackingId,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('กำลังปริ้น Tracking + ใบส่งของ...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.print, size: 20),
            label: const Text('Print Tracking + ใบส่งของ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _dispatchSlot,
            icon: Icon(MdiIcons.truckDeliveryOutline, size: 20),
            label: const Text('ย้ายขึ้นรถแล้ว',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _backToScan,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('กลับไปสแกนต่อ'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textGrey(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── State 4: Dispatch done ──────────────────────────────────
  Widget _buildDispatchDone() {
    final r = _dispatchResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(MdiIcons.truckCheckOutline,
                    color: AppTheme.success, size: 64),
                const SizedBox(height: 12),
                const Text('ส่งขึ้นรถเรียบร้อย',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  '${r.owner}\nช่อง ${r.slotId} • ${r.cartonsCount} กล่อง',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _backToScan,
            icon: Icon(MdiIcons.barcodeScan, size: 20),
            label: const Text('สแกน Carton ต่อ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home_outlined, size: 18),
          label: const Text('กลับหน้าหลัก'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textGrey(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────

  Widget _statusChip(String status) {
    final color = switch (status) {
      'READY' => AppTheme.secondary,
      'SHIPPED' => AppTheme.success,
      'OPEN' => AppTheme.warning,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
