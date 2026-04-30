import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

enum _PackState { scanPallet, packList, orderList, orderParts, success }

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
  PackingDetailResponse? _packDetail;
  PackingOrderResponse? _orderResp;
  ConfirmPackResponse? _confirmResult;

  // current selection
  String _currentPackingId = '';
  String _currentPickOrderId = '';
  String? _selectedPartId;
  // Serial numbers collected for each part (keyed by partId)
  final Map<String, List<String>> _collectedSerials = {};

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
      _packDetail = result.data;
      // ถ้ามี Order เดียว เข้า Order เลย
      if (result.data!.orders.length == 1) {
        _openOrder(result.data!.orders.first.pickOrderId);
      } else {
        _state = _PackState.orderList;
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

    _partScanCtrl.clear();
    setState(() => _selectedPartId = partId);
  }

  Future<void> _confirmPart(String partId, int qty) async {
    final serials = _collectedSerials[partId];
    if (serials != null && serials.isNotEmpty && serials.length != qty) {
      showErrorDialog(context,
          message:
              'จำนวน S/N (${serials.length}) ไม่ตรงกับจำนวนที่ต้อง Pack ($qty)');
      return;
    }

    setState(() => _loading = true);
    final result = await _api.scanPackPart(
      packingId: _currentPackingId,
      pickOrderId: _currentPickOrderId,
      partId: partId,
      qty: qty,
      operatorId: widget.userId,
      serialNumbers:
          (serials != null && serials.length == qty) ? serials : null,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สแกนไม่สำเร็จ');
      return;
    }

    final resp = result.data!;

    // Pack auto-finalize เมื่อสแกนชิ้นสุดท้ายครบทุก Order → ไปหน้า Pack Complete
    if (resp.packFinalized) {
      setState(() {
        _confirmResult = ConfirmPackResponse(
          packingId: resp.packingId,
          status: 'DONE',
          trackingId: resp.trackingId,
          palletShipped: resp.palletReleased,
          completedAt: DateTime.now(),
          message: resp.palletReleased
              ? 'Pack สำเร็จ — Pallet เปล่าพร้อมใช้ใหม่'
              : 'Pack สำเร็จ (ยังเหลือ Pack อื่นใน Pallet)',
        );
        _selectedPartId = null;
        _collectedSerials.remove(partId);
        _state = _PackState.success;
      });
      return;
    }

    setState(() {
      _orderResp = resp;
      _selectedPartId = null;
      _collectedSerials.remove(partId);
    });
    _partScanFocus.requestFocus();
  }

  Future<void> _openSerialScan(
      String partId, int requiredQty, List<String> available) async {
    if (available.isEmpty) {
      showErrorDialog(context,
          message: 'ไม่พบ S/N บน Pallet นี้สำหรับ $partId');
      return;
    }
    final existing = _collectedSerials[partId] ?? [];
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SerialSelectPage(
          partId: partId,
          requiredQty: requiredQty,
          available: available,
          initial: existing,
        ),
      ),
    );
    if (result != null) {
      setState(() => _collectedSerials[partId] = result);
    }
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
      _packDetail = null;
      _currentPackingId = '';
      _currentPickOrderId = '';
      _orderResp = null;
      _selectedPartId = null;
      _collectedSerials.clear();
      _state = _PackState.packList;
    });
  }

  void _resetAll() {
    setState(() {
      _palletResp = null;
      _packDetail = null;
      _orderResp = null;
      _confirmResult = null;
      _currentPackingId = '';
      _currentPickOrderId = '';
      _selectedPartId = null;
      _collectedSerials.clear();
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
                  if (_state == _PackState.orderList) _buildOrderList(),
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
        case _PackState.orderList:
          _state = _PackState.packList;
          _packDetail = null;
          _currentPackingId = '';
          break;
        case _PackState.orderParts:
          // ถ้า Pack มีหลาย Order กลับไป orderList แทน packList
          if (_packDetail != null && _packDetail!.orders.length > 1) {
            _state = _PackState.orderList;
          } else {
            _state = _PackState.packList;
            _packDetail = null;
            _currentPackingId = '';
          }
          _orderResp = null;
          _currentPickOrderId = '';
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
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.barcodeScan, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Scan Pallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สแกน Pallet ที่ต้องการแพ็คสินค้า',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Pallet ID',
            hint: 'Scan Pallet ID',
            controller: _scanCtrl,
            focusNode: _scanFocus,
            onSubmit: _scanPallet,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Scan',
            icon: Icons.search,
            onPressed: _scanPallet,
          ),
        ],
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
        // Pack cards — เฉพาะที่ยัง OPEN (DONE = finalize แล้ว ไป Check-in ต่อ)
        ...pallet.packs.where((p) => p.status == 'OPEN').map((pack) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.warning,
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(pack.packingId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusChip(pack.status),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openPack(pack.packingId),
              ),
            )),
        if (pallet.packs.every((p) => p.status != 'OPEN'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppTheme.success, size: 40),
                    const SizedBox(height: 8),
                    const Text('Pack ทุกกล่องเสร็จแล้ว',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('ไปสแกน Check-in ต่อได้เลย',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
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

  // ── State 3a: Order List (when Pack has multiple Orders) ──────────────────

  Widget _buildOrderList() {
    final pack = _packDetail!;
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
                    Expanded(
                      child: Text(
                        pack.packingId,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _statusChip(pack.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Pallet: ${pack.palletId}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Orders: ${pack.orders.length}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'เลือก Order เพื่อ Pack',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey(context)),
          ),
        ),
        ...pack.orders.map((order) => Card(
              color: order.isDone
                  ? AppTheme.success.withValues(alpha: 0.06)
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      order.isDone ? AppTheme.success : AppTheme.secondary,
                  child: Icon(
                    order.isDone
                        ? Icons.check
                        : MdiIcons.clipboardListOutline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(order.pickOrderId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Parts: ${order.partDoneCount}/${order.partCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusChip(order.status),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openOrder(order.pickOrderId),
              ),
            )),
        const SizedBox(height: 12),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _partScanCtrl,
                      focusNode: _partScanFocus,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'สแกน Part ID',
                        prefixIcon: Icon(MdiIcons.barcodeScan),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _scanPart(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _scanPart,
                    icon: const Icon(Icons.send, color: AppTheme.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),

        // Part list
        ...order.parts.map((part) {
          final isSelected = _selectedPartId == part.partId && !part.isDone;
          final collected = _collectedSerials[part.partId] ?? const [];
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
                  if (isSelected) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text('บน Pallet: ${part.requiredQty} ชิ้น',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const Spacer(),
                        Text('ต้องการ: ${part.remaining} ชิ้น',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openSerialScan(
                                part.partId,
                                part.remaining,
                                part.availableSerials),
                            icon: Icon(MdiIcons.barcodeScan, size: 16),
                            label: Text(
                              collected.length == part.remaining
                                  ? 'S/N ครบ (${collected.length})'
                                  : 'เก็บ S/N (${collected.length}/${part.remaining})',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: collected.length ==
                                      part.remaining
                                  ? AppTheme.success
                                  : AppTheme.secondary,
                              side: BorderSide(
                                color: collected.length == part.remaining
                                    ? AppTheme.success
                                    : AppTheme.secondary,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _confirmPart(part.partId, part.remaining),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('ยืนยัน',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
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
            onPressed: result.palletShipped ? _resetAll : _refreshPackList,
            icon: Icon(
              result.palletShipped
                  ? MdiIcons.barcodeScan
                  : MdiIcons.packageVariantClosed,
              size: 20,
            ),
            label: Text(
              result.palletShipped
                  ? 'Pack Pallet ถัดไป'
                  : 'แพ็คกล่องถัดไปของ Pallet นี้',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
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
      'SHIPPED' => AppTheme.success,
      'DONE' => AppTheme.primary,
      'STAGED' => AppTheme.secondary,
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

// ── Serial Select Page ──────────────────────────────────

class _SerialSelectPage extends StatefulWidget {
  final String partId;
  final int requiredQty;
  final List<String> available;
  final List<String> initial;

  const _SerialSelectPage({
    required this.partId,
    required this.requiredQty,
    required this.available,
    required this.initial,
  });

  @override
  State<_SerialSelectPage> createState() => _SerialSelectPageState();
}

class _SerialSelectPageState extends State<_SerialSelectPage> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  late List<String> _scanned;
  late Set<String> _availableSet;

  @override
  void initState() {
    super.initState();
    _scanned = List.of(widget.initial);
    _availableSet = widget.available.toSet();
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

  void _onScan() {
    final sn = _scanCtrl.text.trim();
    if (sn.isEmpty) return;

    if (_scanned.length >= widget.requiredQty) {
      showErrorDialog(context,
          message: 'สแกนครบ ${widget.requiredQty} ชิ้นแล้ว');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    if (!_availableSet.contains(sn)) {
      showErrorDialog(context,
          message: 'S/N "$sn" ไม่อยู่บน Pallet นี้สำหรับ ${widget.partId}');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    if (_scanned.contains(sn)) {
      showErrorDialog(context, message: 'S/N "$sn" ถูกสแกนไปแล้ว');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    setState(() => _scanned.add(sn));
    _scanCtrl.clear();
    _scanFocus.requestFocus();
  }

  void _remove(String sn) {
    setState(() => _scanned.remove(sn));
    _scanFocus.requestFocus();
  }

  void _clearAll() {
    setState(() => _scanned.clear());
    _scanFocus.requestFocus();
  }

  // DEV: mock autofill ทั้งหมด (long-press ที่ title เพื่อเรียก)
  void _mockFillAll() {
    final take = widget.available.take(widget.requiredQty).toList();
    setState(() {
      _scanned
        ..clear()
        ..addAll(take);
    });
  }

  Future<void> _save() async {
    if (_scanned.isEmpty) {
      Navigator.pop(context, <String>[]);
      return;
    }

    if (_scanned.length != widget.requiredQty) {
      showErrorDialog(context,
          message:
              'ต้องสแกนครบ ${widget.requiredQty} ชิ้น (สแกนแล้ว ${_scanned.length})');
      return;
    }

    Navigator.pop(context, List.of(_scanned));
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _scanned.length >= widget.requiredQty;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _mockFillAll,
          behavior: HitTestBehavior.opaque,
          child: Text('สแกน S/N: ${widget.partId}'),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('S/N ที่สแกน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            )),
                        const Spacer(),
                        Text('${_scanned.length} / ${widget.requiredQty}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isComplete
                                  ? AppTheme.success
                                  : AppTheme.primary,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.requiredQty > 0
                            ? _scanned.length / widget.requiredQty
                            : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(
                            isComplete ? AppTheme.success : AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _scanCtrl,
                            focusNode: _scanFocus,
                            enabled: !isComplete,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'สแกน S/N',
                              prefixIcon: Icon(MdiIcons.barcodeScan),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => _onScan(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: isComplete ? null : _onScan,
                          icon: const Icon(Icons.send,
                              color: AppTheme.primary),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    if (_scanned.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('ล้างทั้งหมด',
                              style: TextStyle(fontSize: 13)),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.warning),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _scanned.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(MdiIcons.barcodeScan,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('ยังไม่มี S/N ที่สแกน',
                                style:
                                    TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                                'สแกนให้ครบ ${widget.requiredQty} ชิ้น หรือกดกลับเพื่อข้าม',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _scanned.length,
                        itemBuilder: (_, i) {
                          final sn = _scanned[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color:
                                AppTheme.primary.withValues(alpha: 0.06),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primary,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                              title: Text(sn,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    color: AppTheme.warning, size: 20),
                                onPressed: () => _remove(sn),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    isComplete
                        ? 'ยืนยัน (${_scanned.length} ชิ้น)'
                        : _scanned.isEmpty
                            ? 'ข้าม (ไม่เก็บ S/N)'
                            : 'ยืนยัน (${_scanned.length}/${widget.requiredQty})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isComplete
                        ? AppTheme.success
                        : _scanned.isEmpty
                            ? AppTheme.textGrey(context)
                            : AppTheme.secondary,
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
    );
  }
}
