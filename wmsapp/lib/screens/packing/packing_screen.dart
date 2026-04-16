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

  // qty controllers per Part (เหมือน Unload)
  final Map<String, TextEditingController> _qtyCtrl = {};
  String? _selectedPartId;

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
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
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

    final part = _orderResp?.parts.where((p) => p.partId == partId).firstOrNull;
    if (part == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" ใน Order นี้');
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

    // select Part + เตรียม qty field
    _qtyCtrl.putIfAbsent(partId, () => TextEditingController());
    _qtyCtrl[partId]!.text = part.remaining.toString();

    setState(() => _selectedPartId = partId);
    _partScanCtrl.clear();
  }

  Future<void> _confirmScanPart(String partId) async {
    final qty = int.tryParse(_qtyCtrl[partId]?.text ?? '') ?? 0;
    if (qty <= 0) {
      showErrorDialog(context, message: 'จำนวนต้องมากกว่า 0');
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
      return;
    }

    setState(() {
      _orderResp = result.data;
      _selectedPartId = null;
      _qtyCtrl.remove(partId);
    });
    _partScanFocus.requestFocus();
  }

  Future<void> _refreshPackList() async {
    // reload pallet data แล้วกลับหน้า packList
    setState(() => _loading = true);
    final palletId = _palletResp!.palletId;
    final result = await _api.scanPalletForPacking(palletId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      // pallet อาจ shipped ไปแล้ว
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่สำเร็จ');
      _resetAll();
      return;
    }

    setState(() {
      _palletResp = result.data;
      _orderResp = null;
      _selectedPartId = null;
      _state = _PackState.packList;
    });
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
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    _qtyCtrl.clear();
    setState(() {
      _palletResp = null;
      _orderResp = null;
      _confirmResult = null;
      _currentPackingId = '';
      _currentPickOrderId = '';
      _selectedPartId = null;
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
        // ยืนยัน Pack (เมื่อทุก Pack DONE)
        if (pallet.packs.every((p) => p.isDone))
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // ใช้ Pack แรก (หรือตัวใดก็ได้ที่ DONE) เพื่อ confirm
                final packId = pallet.packs.first.packingId;
                setState(() => _currentPackingId = packId);
                _confirmPack();
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('ยืนยัน Pack ทั้งหมด',
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
        if (pallet.packs.every((p) => p.isDone))
          const SizedBox(height: 8),
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
        ...order.parts.map((part) {
          final isSelected = _selectedPartId == part.partId && !part.isDone;
          return Card(
            color: part.isDone
                ? AppTheme.success.withValues(alpha: 0.06)
                : isSelected
                    ? AppTheme.primary.withValues(alpha: 0.06)
                    : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: isSelected
                  ? const BorderSide(color: AppTheme.primary, width: 2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
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
                  // ── qty input row (เมื่อ Part ถูกเลือก) ──
                  if (isSelected) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('บน Pallet: ${part.requiredQty} ชิ้น',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const Spacer(),
                        Text('เหลือ: ${part.remaining}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('จำนวน Pack: ',
                            style: TextStyle(fontSize: 13)),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _qtyCtrl[part.partId],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _confirmScanPart(part.partId),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmScanPart(part.partId),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('ยืนยัน',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        // เมื่อ Part ครบใน Order นี้ → กลับไปหน้า packList
        if (allDone)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // reload pack data แล้วกลับ packList
                await _refreshPackList();
              },
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Order นี้เสร็จแล้ว',
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
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text('Pack Complete',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (result.trackingId != null)
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
              label: Text('Print Tracking: ${result.trackingId}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        const SizedBox(height: 12),
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
