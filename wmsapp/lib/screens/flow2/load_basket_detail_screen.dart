// lib/screens/flow2/load_basket_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

class LoadBasketDetailScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final GroupedUnloadItem item;

  const LoadBasketDetailScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.item,
  });

  @override
  State<LoadBasketDetailScreen> createState() => _LoadBasketDetailScreenState();
}

class _LoadBasketDetailScreenState extends State<LoadBasketDetailScreen> {
  final _basketController = TextEditingController();
  final _basketFocus = FocusNode();
  final _qtyController = TextEditingController();

  BasketScanResponse? _basket;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _qtyController.text = '${widget.item.totalQty}';
  }

  // ── สแกน Basket ───────────────────────────
  Future<void> _scanBasket() async {
    final basketId = _basketController.text.trim().toUpperCase();
    if (basketId.isEmpty) return;

    setState(() => _loading = true);

    final result = await ApiService().scanBasket(basketId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Basket นี้');
      _basketController.clear();
      _basketFocus.requestFocus();
      return;
    }

    final basket = result.data!;

    if (basket.status != 'AVAILABLE') {
      showErrorDialog(
        context,
        message:
            'Basket ${basket.basketId} ไม่ว่าง\n'
            'สถานะ: ${basket.status}',
      );
      _basketController.clear();
      _basketFocus.requestFocus();
      return;
    }

    setState(() => _basket = basket);
  }

  // ── Load เข้า Basket แล้วกลับ ─────────────
  Future<void> _loadToBasket() async {
    if (_basket == null) return;

    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      showErrorDialog(context, message: 'กรุณาระบุจำนวนที่ต้องการ Load');
      return;
    }
    if (qty > widget.item.totalQty) {
      showErrorDialog(
        context,
        message: 'จำนวนเกินที่มี (${widget.item.totalQty} ชิ้น)',
      );
      return;
    }

    final confirm = await showConfirmDialog(
      context,
      title: 'Load เข้า Basket',
      message:
          'ใส่ ${widget.item.partId} เข้า ${_basket!.label}?\n'
          '${widget.item.itemDesc}\n'
          'จำนวน: $qty ชิ้น',
      confirmLabel: 'Load',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await ApiService().loadToBasket(
      partId: widget.item.partId,
      basketId: _basket!.basketId,
      qty: qty,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'Load ไม่สำเร็จ');
      return;
    }

    showSuccessSnackbar(
      context,
      'Load สำเร็จ — ${widget.item.partId} x$qty → ${_basket!.label}',
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _basketController.dispose();
    _basketFocus.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        appBar: WmsAppBar(title: 'Load Basket', userName: widget.fullName),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Part Info ─────────────
                _buildPartInfo(),
                const SizedBox(height: 20),

                // ── Qty Input ─────────────
                Text(
                  'จำนวนที่จะ Load เข้าตะกร้า',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: '/ ${widget.item.totalQty} ชิ้น',
                    suffixStyle: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textGrey(context),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Scan Basket ───────────
                Text(
                  'สแกน Basket',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  controller: _basketController,
                  label: 'Basket ID เช่น BKT-A1',
                  hint: 'BKT-A1',
                  onSubmit: _scanBasket,
                ),

                // ── Basket Info + Load Button ──
                if (_basket != null) ...[
                  const SizedBox(height: 16),
                  _buildBasketInfo(),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Load เข้า Basket',
                    icon: MdiIcons.plusBoxOutline,
                    onPressed: _loadToBasket,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartInfo() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.shape, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.item.partId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.item.totalQty} ชิ้น',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'สินค้า', value: widget.item.itemDesc),
          InfoRow(
            label: 'เจ้าของ',
            value: '${widget.item.owner} / ${widget.item.brand}',
          ),
        ],
      ),
    );
  }

  Widget _buildBasketInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.basketOutline, color: AppTheme.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _basket!.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.success,
                  ),
                ),
                Text(
                  _basket!.destination ?? 'ไม่ระบุปลายทาง',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(_basket!.status),
        ],
      ),
    );
  }
}
