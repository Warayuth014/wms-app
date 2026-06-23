// lib/screens/picking/order_detail/picking_order_detail_screen.dart
//
// หน้า 2 ของ Picking flow:
//   - แสดง Pallets ทั้งหมดที่ผูกกับ order (พร้อม station ที่ assign)
//   - แสดง Parts ทั้งหมด + qty
//   - มีช่อง scan pallet — เมื่อ scan ผ่าน → ไปต่อ PickItemsScreen

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/part_thumbnail.dart';
import '../pick_items/pick_items_screen.dart';

class PickingOrderDetailScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String pickOrderId;

  const PickingOrderDetailScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.pickOrderId,
  });

  @override
  State<PickingOrderDetailScreen> createState() =>
      _PickingOrderDetailScreenState();
}

class _PickingOrderDetailScreenState extends State<PickingOrderDetailScreen> {
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  bool _loading = false;
  PickOrderDetailFull? _detail;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getPickOrderDetailFull(widget.pickOrderId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'โหลด order ไม่สำเร็จ');
      return;
    }
    setState(() => _detail = res.data);
  }

  Future<void> _scanPallet() async {
    final palletId = _scanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    // ตรวจว่า pallet อยู่ใน order นี้จริง
    final found =
        _detail?.pallets.any((p) => p.palletId == palletId) ?? false;
    if (!found) {
      showErrorDialog(context,
          message: 'Pallet "$palletId" ไม่อยู่ใน Pick Order นี้');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);
    final res = await _api.assignPickStation(
      palletId: palletId,
      operatorId: widget.userId,
      pickOrderId: widget.pickOrderId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Scan pallet ไม่สำเร็จ');
      return;
    }

    _scanCtrl.clear();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickItemsScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          pickOrderId: widget.pickOrderId,
          initialAssignment: res.data!,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: widget.pickOrderId,
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังโหลด...',
          child: _detail == null
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    children: [
                      _buildHeader(_detail!),
                      const SizedBox(height: 12),
                      _buildScanCard(),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'Pallets',
                        Icons.pallet,
                        '${_detail!.pallets.length}',
                      ),
                      const SizedBox(height: 8),
                      ..._detail!.pallets.map(_buildPalletCard),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(PickOrderDetailFull d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.clipboardListOutline,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(d.pickOrderId,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                _statusPill(d.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(MdiIcons.accountBoxOutline,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('ลูกค้า: ${d.owner.isEmpty ? "-" : d.owner}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
            if (d.customerOrderId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(MdiIcons.clipboardTextOutline,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      d.customerOrderId!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(MdiIcons.barcodeScan, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                const Text('สแกน Pallet เพื่อเริ่ม Pick',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Pallet ID',
                prefixIcon: Icon(MdiIcons.barcodeScan),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _scanPallet(),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _scanPallet,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('สแกน',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textGrey(context)),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(count,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPalletCard(PickOrderPalletInfo p) {
    final atStation = p.stationId != null;
    final accent = atStation ? AppTheme.success : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Pallet header ──
              Container(
                padding: const EdgeInsets.all(12),
                color: accent.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.pallet, color: accent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.palletId,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (atStation) ...[
                                Icon(Icons.place,
                                    size: 12, color: AppTheme.success),
                                const SizedBox(width: 2),
                                Text(
                                  p.stationName ?? p.stationId!,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.success),
                                ),
                              ] else ...[
                                Icon(MdiIcons.robotIndustrialOutline,
                                    size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 2),
                                Text('ยังไม่อยู่ station',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[500])),
                              ],
                              Text('  ·  ',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[400])),
                              Text('${p.totalQty} ชิ้น',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p.palletStatus,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: accent)),
                    ),
                  ],
                ),
              ),

              // ── Parts on this pallet ──
              if (p.parts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('ไม่มี part บน pallet นี้',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500])),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    children: [
                      for (var i = 0; i < p.parts.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: AppTheme.border(context)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: _buildPartRow(p.parts[i]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Part row (nested ใน pallet card) ──────────────
  Widget _buildPartRow(PickOrderPalletPartInfo p) {
    final done = p.isPicked;
    final pct =
        p.allocatedQty > 0 ? p.pickedQty / p.allocatedQty : 0.0;
    final accent = done ? AppTheme.success : AppTheme.primary;

    return Row(
      children: [
        PartThumbnail(imageUrl: p.imageUrl, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.partId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                  if (done)
                    Icon(Icons.check_circle,
                        size: 14, color: AppTheme.success),
                ],
              ),
              if (p.itemDesc.isNotEmpty)
                Text(p.itemDesc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${p.pickedQty}/${p.allocatedQty}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text('ชิ้น',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: accent.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String status) {
    final isPicking = status == 'PICKING';
    final color = isPicking ? AppTheme.success : AppTheme.warning;
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
          Text(status,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: color)),
        ],
      ),
    );
  }
}
