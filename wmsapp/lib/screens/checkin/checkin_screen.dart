import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

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

  bool _loading = false;

  // Pack ที่สแกนไว้รอกด Check-IN (ยังไม่เข้า DB)
  PreviewCheckInResponse? _pendingPack;

  // Slot ที่กำลังดูอยู่ (null = ยังไม่ได้สแกน, อยู่หน้าเริ่ม)
  CheckInSlotDetail? _slotDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────

  Future<void> _scanCarton() async {
    final packingId = _scanCtrl.text.trim().toUpperCase();
    if (packingId.isEmpty) return;

    setState(() => _loading = true);
    final res = await _api.previewCheckIn(packingId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'สแกนไม่สำเร็จ');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    final preview = res.data!;
    _scanCtrl.clear();

    // popup แจ้งปลายทาง
    await _showDestinationDialog(preview);
    if (!mounted) return;

    // ตั้ง pending pack แล้วโหลด slot เดิมถ้ามีจริงใน DB
    setState(() => _pendingPack = preview);
    if (!preview.isNewSlot) {
      await _openSlot(preview.slotId);
    }
    _scanFocus.requestFocus();
  }

  Future<void> _showDestinationDialog(PreviewCheckInResponse p) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              p.isAlreadyCheckedIn
                  ? Icons.warning_amber_rounded
                  : MdiIcons.truckDeliveryOutline,
              color:
                  p.isAlreadyCheckedIn ? AppTheme.warning : AppTheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(p.isAlreadyCheckedIn ? 'สแกนซ้ำ' : 'ส่งปลายทาง',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.packingId,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (!p.isAlreadyCheckedIn && p.dispatchDestination != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    p.dispatchDestination!,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text('ช่อง ${p.slotId}',
                style: TextStyle(color: Colors.grey[600])),
            if (p.isAlreadyCheckedIn) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.warning, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Pack นี้ถูก check-in ไปแล้ว',
                        style: TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: p.isAlreadyCheckedIn
                  ? AppTheme.warning
                  : AppTheme.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('รับทราบ',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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

    setState(() => _slotDetail = res.data);
  }

  Future<void> _confirmCheckIn() async {
    final pack = _pendingPack;
    if (pack == null) return;

    if (pack.isAlreadyCheckedIn) {
      showErrorDialog(context,
          message: 'Pack ${pack.packingId} ถูก check-in ไปแล้ว');
      return;
    }

    setState(() => _loading = true);
    final res = await _api.scanCheckIn(
      packingId: pack.packingId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Check-IN ไม่สำเร็จ');
      return;
    }

    final scanResult = res.data!;

    // ถ้าครบทุกกล่อง → auto complete + auto dispatch เงียบ ๆ
    if (scanResult.isReadyToComplete) {
      await _autoCompleteSlot(scanResult.slotId);
      if (!mounted) return;
      await _autoDispatchSlot(scanResult.slotId);
      if (!mounted) return;
    }

    // เคลียร์ pending + refresh slot
    setState(() => _pendingPack = null);
    await _openSlot(scanResult.slotId);
    _scanFocus.requestFocus();
  }

  Future<void> _autoCompleteSlot(String slotId) async {
    final res = await _api.completeCheckIn(
      slotId: slotId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Complete ไม่สำเร็จ');
    }
  }

  Future<void> _autoDispatchSlot(String slotId) async {
    final res = await _api.dispatchCheckIn(
      slotId: slotId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Dispatch ไม่สำเร็จ');
    }
  }

  void _backToScan() {
    setState(() {
      _slotDetail = null;
      _pendingPack = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onSlotPage = _slotDetail != null || _pendingPack != null;
    return PopScope(
      canPop: !onSlotPage,
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
                  onSlotPage ? _buildSlotDetail() : _buildScan(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Page: Scan (หน้าแรก) ──────────────────────────────────
  Widget _buildScan() {
    return Card(
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
    );
  }

  // ── Page: Slot Detail ──────────────────────────────────
  Widget _buildSlotDetail() {
    final slot = _slotDetail;
    final pending = _pendingPack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Pack details card (บนสุด) — มีเฉพาะเมื่อมี pending
        if (pending != null) ...[
          _buildPendingPackCard(pending),
          const SizedBox(height: 12),
        ],

        // 2) ความคืบหน้า Customer Order
        if (slot != null) ...[
          _buildPipelineCard(slot),
          const SizedBox(height: 12),
        ],

        // 3) สแกน Carton เพิ่ม
        if (slot != null && (slot.status == 'OPEN' || slot.status == 'READY'))
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

        // 4) รายการ Packing ที่ check-in แล้ว (stacked)
        if (slot != null) ...slot.cartons.map(_buildCartonItem),

        const SizedBox(height: 12),
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

  // ── Pack preview card + ปุ่ม Check-IN ────────────────────
  Widget _buildPendingPackCard(PreviewCheckInResponse p) {
    final disabled = p.isAlreadyCheckedIn;
    final badgeColor = disabled ? AppTheme.warning : AppTheme.primary;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.packageVariantClosed,
                    color: badgeColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.packingId,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                _statusChip(p.packStatus),
              ],
            ),
            const SizedBox(height: 6),
            Text('ลูกค้า: ${p.owner}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(MdiIcons.packageVariantClosed,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${p.itemCount} ชิ้น',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                const SizedBox(width: 12),
                Icon(MdiIcons.clipboardListOutline,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${p.orderCount} Order',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
            if (disabled) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Pack นี้ถูก check-in ไปแล้ว',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: disabled ? null : _confirmCheckIn,
                icon: Icon(MdiIcons.checkboxMarkedCircleOutline, size: 20),
                label: const Text('Check-IN',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carton list item (ของที่ check-in ไปแล้ว) ─────────────
  Widget _buildCartonItem(CheckInCartonItem c) {
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.success.withValues(alpha: 0.15),
          child:
              const Icon(Icons.check, color: AppTheme.success, size: 16),
        ),
        title: Text(c.packingId,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.packageVariantClosed,
                    size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${c.itemCount} ชิ้น',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[700])),
                Text('  ·  ',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[400])),
                Icon(MdiIcons.clipboardListOutline,
                    size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${c.orderCount} Order',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
            if (c.trackingId != null)
              Text('TRK: ${c.trackingId}',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: Text(
          _formatTime(c.scannedAt),
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ),
    );
  }

  // ── Pipeline card ─────────────────────────────────────────
  Widget _buildPipelineCard(CheckInSlotDetail slot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.progressClock,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 6),
                const Text('ความคืบหน้า Customer Order',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (slot.customerOrderId != null)
                  Text(slot.customerOrderId!,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _pipelineColumn(
                  label: 'Pick',
                  icon: MdiIcons.handExtendedOutline,
                  done: slot.pickDone,
                  total: slot.pipelineTotal,
                  color: AppTheme.primary,
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _pipelineColumn(
                  label: 'Pack',
                  icon: MdiIcons.packageVariantClosed,
                  done: slot.packDone,
                  total: slot.pipelineTotal,
                  color: AppTheme.warning,
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: _pipelineColumn(
                  label: 'Check-IN',
                  icon: MdiIcons.checkboxMarkedCircleOutline,
                  done: slot.checkInDone,
                  total: slot.pipelineTotal,
                  color: AppTheme.success,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipelineColumn({
    required String label,
    required IconData icon,
    required int done,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? done / total : 0.0;
    final complete = total > 0 && done >= total;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: complete ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: color.withValues(alpha: complete ? 0.5 : 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 4),
          Text('$done/$total',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────

  Widget _statusChip(String status) {
    final color = switch (status) {
      'READY' => AppTheme.secondary,
      'SHIPPED' => AppTheme.success,
      'OPEN' => AppTheme.warning,
      'DONE' => AppTheme.primary,
      'STAGED' => AppTheme.secondary,
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
