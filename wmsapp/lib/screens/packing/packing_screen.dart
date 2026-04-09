import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

enum _PackState { scanPallet, packList, orderParts, success }

class PackingScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String? initialPalletId;

  const PackingScreen({
    super.key,
    required this.userId,
    required this.fullName,
    this.initialPalletId,
  });

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _partScanCtrl = TextEditingController();
  final _partScanFocus = FocusNode();

  _PackState _state = _PackState.scanPallet;
  bool _loading = false;

  // data
  PackingPalletResponse? _palletResp;
  PackingOrderResponse? _orderResp;
  ConfirmPackResponse? _confirmResult;

  // current selection
  String _currentPackingId = '';
  String _currentPickOrderId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPalletId != null &&
          widget.initialPalletId!.isNotEmpty) {
        _scanCtrl.text = widget.initialPalletId!;
        _scanPallet();
      } else {
        _scanFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _partScanCtrl.dispose();
    _partScanFocus.dispose();
    super.dispose();
  }

  // ── API calls ──────────────────────────────────

  Future<void> _scanPallet() async {
    final palletId = _scanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.scanPalletForPacking(palletId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Pallet');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    setState(() {
      _palletResp = result.data;
      _state = _PackState.packList;
    });
  }

  Future<void> _openPack(String packingId) async {
    setState(() => _loading = true);
    final result = await _api.getPack(packingId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลด Pack ไม่สำเร็จ');
      return;
    }

    setState(() {
      _currentPackingId = packingId;
      // ถ้ามี Order เดียว เข้า Order เลย
      if (result.data!.orders.length == 1) {
        _openOrder(result.data!.orders.first.pickOrderId);
      }
    });
  }

  Future<void> _openOrder(String pickOrderId) async {
    setState(() => _loading = true);
    final result = await _api.getPackOrder(
      packingId: _currentPackingId,
      pickOrderId: pickOrderId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
          context, message: result.error ?? 'โหลด Order ไม่สำเร็จ');
      return;
    }

    setState(() {
      _orderResp = result.data;
      _currentPickOrderId = pickOrderId;
      _state = _PackState.orderParts;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _partScanFocus.requestFocus();
    });
  }

  Future<void> _scanPart() async {
    final partId = _partScanCtrl.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    // หา Part ใน list
    final part = _orderResp?.parts.where((p) => p.partId == partId).firstOrNull;
    if (part == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" บน Pallet นี้');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    if (part.isDone) {
      showErrorDialog(context, message: 'Part "$partId" สแกนครบแล้ว');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    // แสดง dialog ระบุจำนวน
    final qty = await _showQtyDialog(part);
    if (qty == null || qty <= 0) {
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);
    final result = await _api.scanPackPart(
      packingId: _currentPackingId,
      pickOrderId: _currentPickOrderId,
      partId: partId,
      qty: qty,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สแกนไม่สำเร็จ');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    setState(() {
      _orderResp = result.data;
    });
    _partScanCtrl.clear();
    _partScanFocus.requestFocus();
  }

  Future<int?> _showQtyDialog(PackingPartItem part) async {
    final qtyCtrl = TextEditingController(text: part.remaining.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('สแกน ${part.partId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(part.itemDesc,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('ต้องการ: ${part.requiredQty}  สแกนแล้ว: ${part.scannedQty}  เหลือ: ${part.remaining}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'จำนวน',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                final v = int.tryParse(qtyCtrl.text) ?? 0;
                Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(qtyCtrl.text) ?? 0;
              Navigator.pop(ctx, v);
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPack() async {
    setState(() => _loading = true);
    final result = await _api.confirmPack(
      packingId: _currentPackingId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
          context, message: result.error ?? 'ยืนยัน Pack ไม่สำเร็จ');
      return;
    }

    setState(() {
      _confirmResult = result.data;
      _state = _PackState.success;
    });
  }

  void _resetAll() {
    setState(() {
      _palletResp = null;
      _orderResp = null;
      _confirmResult = null;
      _currentPackingId = '';
      _currentPickOrderId = '';
      _scanCtrl.clear();
      _partScanCtrl.clear();
      _state = _PackState.scanPallet;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _PackState.scanPallet,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: WmsAppBar(title: 'Packing', userName: widget.fullName),
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
                  if (_state == _PackState.scanPallet) _buildScanPallet(),
                  if (_state == _PackState.packList) _buildPackList(),
                  if (_state == _PackState.orderParts) _buildOrderParts(),
                  if (_state == _PackState.success) _buildSuccess(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    setState(() {
      switch (_state) {
        case _PackState.packList:
          _resetAll();
          break;
        case _PackState.orderParts:
          _state = _PackState.packList;
          _orderResp = null;
          break;
        case _PackState.success:
          _resetAll();
          break;
        default:
          break;
      }
    });
  }

  // ── State 1: Scan Pallet ──────────────────────────────────

  Widget _buildScanPallet() {
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
                const Text('สแกน Pallet',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Pallet ID',
                prefixIcon: Icon(MdiIcons.barcodeScan),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _scanPallet(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanPallet,
                icon: const Icon(Icons.search, size: 20),
                label: const Text('ค้นหา'),
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

  // ── State 2: Pack List ──────────────────────────────────

  Widget _buildPackList() {
    final pallet = _palletResp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pallet header
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
                    Text(pallet.palletId,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _statusChip(pallet.status),
                  ],
                ),
                if (pallet.location != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Location: ${pallet.location}',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Pack cards
        ...pallet.packs.map((pack) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      pack.isDone ? AppTheme.success : AppTheme.warning,
                  child: Icon(
                    pack.isDone ? Icons.check : Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(pack.packingId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Orders: ${pack.orderDoneCount}/${pack.orderCount}  •  ${pack.status}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPack(pack.packingId),
              ),
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _resetAll,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('สแกน Pallet อื่น'),
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

  // ── State 3: Order Parts (scan + list) ──────────────────────────────────

  Widget _buildOrderParts() {
    final order = _orderResp!;
    final allDone = order.parts.every((p) => p.isDone);

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
                    Icon(MdiIcons.clipboardListOutline,
                        color: AppTheme.secondary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pack: $_currentPackingId',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Order: $_currentPickOrderId',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text('Pallet: ${_palletResp?.palletId ?? ""}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 8),
                // progress
                _buildProgress(order),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // scan Part field (ถ้ายังไม่ DONE)
        if (order.status != 'DONE')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _partScanCtrl,
                focusNode: _partScanFocus,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'สแกน Part ID',
                  prefixIcon: Icon(MdiIcons.barcodeScan),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _scanPart(),
              ),
            ),
          ),
        const SizedBox(height: 8),

        // Part list
        ...order.parts.map((part) => Card(
              color: part.isDone
                  ? AppTheme.success.withValues(alpha: 0.06)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // image or icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: part.imageUrl != null
                          ? FutureBuilder<String>(
                              future: _api.getImageFullUrl(part.imageUrl!),
                              builder: (_, snap) {
                                if (!snap.hasData) return const SizedBox();
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(snap.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_not_supported)),
                                );
                              },
                            )
                          : const Icon(Icons.inventory_2_outlined,
                              color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    // info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(part.partId,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(part.itemDesc,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${part.owner} / ${part.brand}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    // qty
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${part.scannedQty} / ${part.requiredQty}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: part.isDone
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                        ),
                        if (part.isDone)
                          const Icon(Icons.check_circle,
                              color: AppTheme.success, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),

        // Confirm Pack button (เมื่อทุก Part ครบ)
        if (allDone)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmPack,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('ยืนยัน Pack',
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
          onPressed: _handleBack,
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

  Widget _buildProgress(PackingOrderResponse order) {
    final total = order.parts.fold<int>(0, (s, p) => s + p.requiredQty);
    final scanned = order.parts.fold<int>(0, (s, p) => s + p.scannedQty);
    final pct = total > 0 ? scanned / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$scanned / $total',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
            valueColor:
                AlwaysStoppedAnimation(pct >= 1.0 ? AppTheme.success : AppTheme.primary),
          ),
        ),
      ],
    );
  }

  // ── State 4: Success ──────────────────────────────────

  Widget _buildSuccess() {
    final result = _confirmResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  result.palletShipped
                      ? Icons.local_shipping_outlined
                      : Icons.check_circle_outline,
                  color: AppTheme.success,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(result.message,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                if (result.trackingId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Tracking: ${result.trackingId}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetAll,
            icon: Icon(MdiIcons.barcodeScan, size: 20),
            label: const Text('Pack Pallet ถัดไป',
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
      'DONE' || 'SHIPPED' => AppTheme.success,
      'OPEN' || 'PACKED' => AppTheme.warning,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
