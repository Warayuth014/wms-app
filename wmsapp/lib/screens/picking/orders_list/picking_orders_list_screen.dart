// lib/screens/picking/orders_list/picking_orders_list_screen.dart
//
// หน้า 1 ของ Picking flow:
//   - Sticky top: summary (Waiting/Picking/รวม)
//   - Scrollable middle: รายการ Pick Orders (WAITING + PICKING)
//   - Sticky bottom: ส่ง Pallet → ASRS / ZONE_PACK / PICK

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../order_detail/picking_order_detail_screen.dart';

class PickingOrdersListScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PickingOrdersListScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PickingOrdersListScreen> createState() =>
      _PickingOrdersListScreenState();
}

class _PickingOrdersListScreenState extends State<PickingOrdersListScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<PickOrderListItem> _orders = [];

  // ── Scan Pallet panel — auto-route ──
  final _sendPalletCtrl = TextEditingController();
  final _sendPalletFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sendPalletCtrl.dispose();
    _sendPalletFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getPickOrdersList();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'โหลด orders ไม่สำเร็จ');
      return;
    }
    setState(() => _orders = res.data!);
  }

  Future<void> _sendPallet() async {
    final palletId = _sendPalletCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      _sendPalletFocus.requestFocus();
      return;
    }

    // ── 1) Preview ──
    setState(() => _loading = true);
    final preview = await _api.previewReturnPallet(palletId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!preview.success) {
      showErrorDialog(context,
          message: preview.error ?? 'ไม่พบ Pallet "$palletId"');
      _sendPalletFocus.requestFocus();
      return;
    }

    final info = preview.data!;
    if (!info.canReturn) {
      showErrorDialog(context, message: info.reason);
      _sendPalletFocus.requestFocus();
      return;
    }

    // ── 2) Show popup confirm ──
    final dest = info.destination!;
    final destLabel = dest == 'ZONE_PACK' ? 'ZONE PACK' : dest;
    final destIcon =
        dest == 'ZONE_PACK' ? MdiIcons.truckDeliveryOutline : MdiIcons.warehouse;
    final btnText =
        dest == 'ZONE_PACK' ? 'ส่งไป ZONE PACK' : 'ส่งกลับ ASRS';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(palletId,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.reason,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textGrey(context))),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: Icon(destIcon, size: 18),
                label: Text(btnText,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textGrey(context),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('ปิด'),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      _sendPalletFocus.requestFocus();
      return;
    }

    // ── 3) Execute ──
    setState(() => _loading = true);
    final ok = await _api.returnPallet(
      palletId: palletId,
      destination: dest,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok.success) {
      showErrorDialog(context,
          message: ok.error ?? 'ส่ง $palletId → $destLabel ไม่สำเร็จ');
      _sendPalletFocus.requestFocus();
      return;
    }

    showSuccessSnackbar(context, '📦 ส่ง $palletId → $destLabel แล้ว');
    _sendPalletCtrl.clear();
    _sendPalletFocus.requestFocus();
  }

  Future<void> _openOrder(PickOrderListItem o) async {
    if (o.isWaiting) {
      _showWaitingDialog(o);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickingOrderDetailScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          pickOrderId: o.pickOrderId,
        ),
      ),
    );
    _load(); // refresh after returning
  }

  void _showWaitingDialog(PickOrderListItem o) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(MdiIcons.robotIndustrialOutline,
                color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('รอ Robot',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.pickOrderId,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Robot กำลังขน pallet ของ order นี้มา\n'
              'รอ status เปลี่ยนเป็น PICKING แล้วค่อยเริ่มเก็บของ',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('รับทราบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitingCount = _orders.where((o) => o.isWaiting).length;
    final pickingCount = _orders.where((o) => o.isPicking).length;

    return Scaffold(
      appBar: WmsAppBar(title: 'Pick Orders', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังโหลด...',
          child: Column(
            children: [
              // ── Sticky top: Summary ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _buildSummary(waitingCount, pickingCount),
              ),
              // ── Scrollable middle: Pick Orders list ──
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _orders.isEmpty && !_loading
                      ? _buildEmpty()
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          children: _orders.map(_buildOrderCard).toList(),
                        ),
                ),
              ),
              // ── Sticky bottom: Send Pallet panel ──
              _buildSendPalletPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scan Pallet sticky panel — backend auto-decides destination ──
  Widget _buildSendPalletPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(top: BorderSide(color: Color(0xFFE4EAF2))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text(
                  'Scan Pallet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sendPalletCtrl,
              focusNode: _sendPalletFocus,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Pallet ID',
                hintText: 'Scan Pallet ID',
                prefixIcon:
                    const Icon(Icons.qr_code_scanner, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, size: 18),
                  color: AppTheme.primary,
                  onPressed: _sendPallet,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _sendPallet(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _sendPallet,
              icon: const Icon(Icons.search, size: 18),
              label: const Text(
                'Scan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(int waiting, int picking) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statTile('Waiting', waiting, AppTheme.primary,
                MdiIcons.robotIndustrialOutline),
            _statTile('Picking', picking, AppTheme.warning,
                Icons.local_shipping_outlined),
            _statTile('รวม', _orders.length, AppTheme.success,
                MdiIcons.formatListChecks),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, int n, Color color, IconData icon) => Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text('$n',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600])),
        ],
      );

  Widget _buildOrderCard(PickOrderListItem o) {
    final accent = o.isPicking ? AppTheme.warning : AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openOrder(o),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: accent.withValues(alpha: 0.45), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.pickOrderId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2),
                                ),
                              ),
                              _statusPill(o.status, accent),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (o.owner.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(MdiIcons.accountBoxOutline,
                                    size: 13, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(o.owner,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[700])),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              _metric(MdiIcons.packageVariantClosed,
                                  '${o.totalRequiredQty}', 'ชิ้น'),
                              const SizedBox(width: 12),
                              _metric(MdiIcons.formatListBulletedSquare,
                                  '${o.partCount}', 'parts'),
                              const SizedBox(width: 12),
                              _metric(
                                  Icons.pallet, '${o.palletCount}', 'pallets'),
                            ],
                          ),
                          if (o.isWaiting) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(MdiIcons.robotIndustrialOutline,
                                    size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'รอ Robot ขนของมาถึง station',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.touch_app,
                                    size: 13, color: AppTheme.warning),
                                const SizedBox(width: 4),
                                Text(
                                  'แตะเพื่อดู pallets + เริ่ม pick',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (o.isPicking)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.chevron_right,
                          color: Colors.grey[400], size: 26),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      );

  Widget _statusPill(String status, Color color) {
    final label = status == 'PICKING' ? 'PICKING' : 'WAITING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(MdiIcons.clipboardListOutline,
                  size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('ไม่มี Pick Order',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                'ลากลงเพื่อ refresh\nหรือสร้าง test order ที่ Dev Tools',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
