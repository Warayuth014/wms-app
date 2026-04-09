import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class LoadToBasketScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const LoadToBasketScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<LoadToBasketScreen> createState() => _LoadToBasketScreenState();
}

class _LoadToBasketScreenState extends State<LoadToBasketScreen> {
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  bool _loading = false;
  UnloadedItemsResponse? _data;
  UnloadedItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final result = await _api.getUnloadedItems();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่สำเร็จ');
      return;
    }
    setState(() => _data = result.data);
  }

  void _onScanPart() {
    final partId = _scanCtrl.text.trim().toUpperCase();
    _scanCtrl.clear();
    if (partId.isEmpty) return;

    final items = _data?.items.where((i) => i.partId == partId && !i.isDone).toList() ?? [];

    if (items.isEmpty) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" ที่รอ Load เข้า Basket');
      _scanFocus.requestFocus();
      return;
    }

    setState(() => _selectedItem = items.first);
    _showBasketDialog(items.first);
  }

  Future<void> _showBasketDialog(UnloadedItem item) async {
    final basketCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: item.qtyRemaining.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(MdiIcons.basketOutline, color: AppTheme.teal, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Load เข้า Basket', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Part info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.partId,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(item.itemDesc,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('Lot: ${item.lotNumber ?? "-"}  |  เหลือ: ${item.qtyRemaining}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Basket ID
            TextField(
              controller: basketCtrl,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Basket ID',
                prefixIcon: Icon(MdiIcons.basketOutline),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Qty
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'จำนวน',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      _scanFocus.requestFocus();
      return;
    }

    final basketId = basketCtrl.text.trim().toUpperCase();
    final qty = int.tryParse(qtyCtrl.text) ?? 0;

    if (basketId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาระบุ Basket ID');
      _scanFocus.requestFocus();
      return;
    }
    if (qty <= 0) {
      showErrorDialog(context, message: 'จำนวนต้องมากกว่า 0');
      _scanFocus.requestFocus();
      return;
    }

    await _doLoad(item, basketId, qty);
  }

  Future<void> _doLoad(UnloadedItem item, String basketId, int qty) async {
    setState(() => _loading = true);
    final result = await _api.loadToBasket(
      partId: item.partId,
      lotNumber: item.lotNumber,
      basketId: basketId,
      qty: qty,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'Load ไม่สำเร็จ');
      _scanFocus.requestFocus();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.data!.message),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() => _selectedItem = null);
    await _loadItems();
    _scanFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Load to Basket', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังประมวลผล...',
          child: Column(
            children: [
              // Scan Part bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: WmsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(MdiIcons.barcodeScan, color: AppTheme.teal, size: 20),
                          const SizedBox(width: 8),
                          const Text('สแกน Part เพื่อ Load เข้า Basket',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ScanTextField(
                        label: 'Part ID',
                        hint: 'สแกนบาร์โค้ด Part',
                        controller: _scanCtrl,
                        focusNode: _scanFocus,
                        onSubmit: _onScanPart,
                      ),
                    ],
                  ),
                ),
              ),
              // Summary
              if (_data != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(MdiIcons.clipboardListOutline,
                          size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'รายการ Unload: ${_data!.totalItems}  |  Load แล้ว: ${_data!.totalLoaded}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // Item list
              Expanded(
                child: _data == null || _data!.items.isEmpty
                    ? Center(
                        child: Text(
                          _data == null ? '' : 'ไม่มีรายการที่รอ Load',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadItems,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _data!.items.length,
                          itemBuilder: (_, i) =>
                              _buildItemCard(_data!.items[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(UnloadedItem item) {
    final isSelected = _selectedItem?.partId == item.partId &&
        _selectedItem?.lotNumber == item.lotNumber;
    final isDone = item.isDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? const BorderSide(color: AppTheme.teal, width: 2)
            : BorderSide.none,
      ),
      color: isDone ? AppTheme.success.withValues(alpha: 0.06) : null,
      child: InkWell(
        onTap: isDone ? null : () => _showBasketDialog(item),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // image / icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.imageUrl != null
                    ? FutureBuilder<String>(
                        future: _api.getImageFullUrl(item.imageUrl!),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const SizedBox();
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(snap.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported)),
                          );
                        },
                      )
                    : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              // info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.partId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(item.itemDesc,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        if (item.lotNumber != null)
                          Text('Lot: ${item.lotNumber}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        if (item.basketId != null) ...[
                          const SizedBox(width: 6),
                          Icon(MdiIcons.basketOutline, size: 12, color: AppTheme.teal),
                          const SizedBox(width: 2),
                          Text(item.basketId!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.teal,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // qty
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.qtyLoaded}/${item.qtyUnloaded}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDone ? AppTheme.success : AppTheme.primary,
                    ),
                  ),
                  if (isDone)
                    const Icon(Icons.check_circle,
                        color: AppTheme.success, size: 16)
                  else
                    Text('เหลือ ${item.qtyRemaining}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
