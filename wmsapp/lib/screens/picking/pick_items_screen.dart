// lib/screens/picking/pick_items_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

class PickItemsScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final int sessionId;
  final String packPalletId;

  const PickItemsScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.sessionId,
    required this.packPalletId,
  });

  @override
  State<PickItemsScreen> createState() => _PickItemsScreenState();
}

class _PickItemsScreenState extends State<PickItemsScreen> {
  final _pickPalletController = TextEditingController();
  final _api = ApiService();

  bool _loading = false;
  PickPalletResponse? _pickPallet;
  String? _currentPickPalletId;

  // track qty ที่จะ pick สำหรับแต่ละ part
  final Map<String, TextEditingController> _qtyControllers = {};

  // ── Scan Pick Pallet ───────────────────────
  Future<void> _scanPickPallet() async {
    final palletId = _pickPalletController.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    // ไม่ให้ scan pack pallet ตัวเอง
    if (palletId == widget.packPalletId) {
      showErrorDialog(context, message: 'ไม่สามารถ pick จาก Pack Pallet ตัวเองได้');
      _pickPalletController.clear();
      return;
    }

    setState(() => _loading = true);

    final result = await _api.scanPickPallet(palletId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Pallet นี้');
      _pickPalletController.clear();
      return;
    }

    // ตั้ง qty controllers
    _qtyControllers.clear();
    for (final item in result.data!.items) {
      _qtyControllers[item.partId] =
          TextEditingController(text: '${item.qty}');
    }

    setState(() {
      _pickPallet = result.data;
      _currentPickPalletId = palletId;
    });
  }

  // ── Pick single item ───────────────────────
  Future<void> _pickItem(PickPalletItem item) async {
    final qtyText = _qtyControllers[item.partId]?.text.trim() ?? '';
    final qty = int.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      showWarningSnackbar(context, 'กรุณาระบุจำนวนที่ถูกต้อง');
      return;
    }
    if (qty > item.qty) {
      showWarningSnackbar(context, 'จำนวนเกินกว่าที่มีบน Pallet (${item.qty})');
      return;
    }

    setState(() => _loading = true);

    final result = await _api.pickItem(
      sessionId: widget.sessionId,
      pickPalletId: _currentPickPalletId!,
      partId: item.partId,
      qtyPicked: qty,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'Pick ไม่สำเร็จ');
      return;
    }

    showSuccessSnackbar(context, 'Pick ${item.partId} x$qty สำเร็จ');

    // รีเฟรชข้อมูล pick pallet
    if (result.data!.remainingOnPickPallet == 0) {
      // Pallet ว่างแล้ว → ถามส่งกลับ
      _showReturnDialog(isEmpty: true);
    } else {
      // รีเฟรช pallet data
      await _refreshPickPallet();
    }
  }

  // ── Pick All items ─────────────────────────
  Future<void> _pickAllItems() async {
    if (_pickPallet == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'Pick ทั้งหมด',
      message: 'ต้องการ pick สินค้าทุกรายการจาก Pallet นี้?',
      confirmLabel: 'Pick ทั้งหมด',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    for (final item in _pickPallet!.items) {
      final qtyText = _qtyControllers[item.partId]?.text.trim() ?? '';
      final qty = int.tryParse(qtyText) ?? item.qty;
      if (qty <= 0) continue;

      final result = await _api.pickItem(
        sessionId: widget.sessionId,
        pickPalletId: _currentPickPalletId!,
        partId: item.partId,
        qtyPicked: qty,
        operatorId: widget.userId,
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() => _loading = false);
        showErrorDialog(context,
            message: 'Pick ${item.partId} ล้มเหลว: ${result.error}');
        return;
      }
    }

    setState(() => _loading = false);
    if (!mounted) return;

    showSuccessSnackbar(context, 'Pick ทุกรายการสำเร็จ');
    _showReturnDialog(isEmpty: true);
  }

  // ── Refresh pick pallet data ───────────────
  Future<void> _refreshPickPallet() async {
    if (_currentPickPalletId == null) return;

    final result = await _api.scanPickPallet(_currentPickPalletId!);
    if (!mounted) return;

    if (!result.success) {
      // ไม่มีของเหลือแล้ว
      _showReturnDialog(isEmpty: true);
      return;
    }

    _qtyControllers.clear();
    for (final item in result.data!.items) {
      _qtyControllers[item.partId] =
          TextEditingController(text: '${item.qty}');
    }

    setState(() => _pickPallet = result.data);
  }

  // ── Return Pick Pallet Dialog ──────────────
  Future<void> _showReturnDialog({required bool isEmpty}) async {
    final confirm = await showConfirmDialog(
      context,
      title: isEmpty ? 'Pallet ว่างแล้ว' : 'ส่ง Pick Pallet กลับ',
      message: isEmpty
          ? 'Pick Pallet $_currentPickPalletId ว่างแล้ว\nส่งกลับ ASRS?'
          : 'ส่ง Pick Pallet $_currentPickPalletId กลับ ASRS?\n(ยังมีสินค้าเหลืออยู่)',
      confirmLabel: 'ส่งกลับ',
    );

    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await _api.returnPickPallet(
      palletId: _currentPickPalletId!,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ส่งกลับไม่สำเร็จ');
      return;
    }

    showSuccessSnackbar(context, 'ส่ง Pallet กลับ ASRS สำเร็จ');

    // ถามว่าจะ pick pallet อีกตัวหรือกลับ
    if (!mounted) return;
    final pickMore = await showConfirmDialog(
      context,
      title: 'Pick ต่อ?',
      message: 'ต้องการ scan Pick Pallet อีกตัวหรือไม่?',
      confirmLabel: 'Pick ต่อ',
    );

    if (pickMore && mounted) {
      setState(() {
        _pickPallet = null;
        _currentPickPalletId = null;
        _qtyControllers.clear();
        _pickPalletController.clear();
      });
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Pick Items', userName: widget.fullName),
      body: LoadingOverlay(
        loading: _loading,
        message: 'กำลังดำเนินการ...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Pack Pallet Info Bar ────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Pack Pallet: ${widget.packPalletId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Session #${widget.sessionId}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── No Pick Pallet: Scan ───────
              if (_pickPallet == null) ...[
                WmsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              color: AppTheme.secondary),
                          SizedBox(width: 8),
                          Text(
                            'Scan Pick Pallet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'สแกน Pallet ที่จะหยิบสินค้าออก (ต้นทาง)',
                        style:
                            TextStyle(fontSize: 13, color: AppTheme.textGrey),
                      ),
                      const SizedBox(height: 12),
                      ScanTextField(
                        label: 'Pick Pallet ID',
                        hint: 'Scan Pick Pallet ID',
                        controller: _pickPalletController,
                        onSubmit: _scanPickPallet,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Scan',
                        icon: Icons.search,
                        onPressed: _scanPickPallet,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Back button
                DangerButton(
                  label: 'กลับ',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pop(context),
                ),
              ],

              // ── Pick Pallet Loaded ─────────
              if (_pickPallet != null) ...[
                // Pallet Info
                WmsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping,
                              color: AppTheme.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pick Pallet: $_currentPickPalletId',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondary,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(_pickPallet!.type),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_pickPallet!.items.length} รายการบน Pallet',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Pick All Button
                PrimaryButton(
                  label: 'Pick ทั้งหมด',
                  icon: Icons.select_all,
                  onPressed: _pickAllItems,
                ),
                const SizedBox(height: 12),

                // ── Items List ────────────────
                const Row(
                  children: [
                    Icon(Icons.list_alt, color: AppTheme.textPrimary, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'รายการสินค้า',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ..._pickPallet!.items.map((item) => _buildItemCard(item)),

                const SizedBox(height: 16),

                // Return Pallet button
                Row(
                  children: [
                    Expanded(
                      child: DangerButton(
                        label: 'ส่ง Pallet กลับ',
                        icon: Icons.keyboard_return,
                        onPressed: () =>
                            _showReturnDialog(isEmpty: false),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(PickPalletItem item) {
    final qtyCtrl = _qtyControllers[item.partId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part ID + Condition
          Row(
            children: [
              Expanded(
                child: Text(
                  item.partId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              StatusBadge(item.condition),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.itemDesc,
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.owner} / ${item.brand}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),

          // Lot & Expiry
          if (item.lotNumber != null || item.expiredDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (item.lotNumber != null) ...[
                    const Icon(Icons.tag, size: 12, color: AppTheme.textGrey),
                    const SizedBox(width: 2),
                    Text(item.lotNumber!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey)),
                    const SizedBox(width: 8),
                  ],
                  if (item.expiredDate != null) ...[
                    const Icon(Icons.calendar_today,
                        size: 12, color: AppTheme.textGrey),
                    const SizedBox(width: 2),
                    Text(item.expiredDate!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textGrey)),
                  ],
                ],
              ),
            ),

          const Divider(height: 16),

          // Qty + Pick button
          Row(
            children: [
              Text(
                'มี: ${item.qty}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                height: 40,
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _pickItem(item),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Pick'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pickPalletController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}
