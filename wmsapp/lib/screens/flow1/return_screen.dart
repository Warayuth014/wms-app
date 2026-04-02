import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import '../../widgets/part_thumbnail.dart';

class ReturnScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const ReturnScreen({super.key, required this.userId, required this.fullName});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  // ── State ─────────────────────────────────
  final _orderController = TextEditingController();
  final _orderFocus = FocusNode();

  OrderResponse? _order;
  int? _returnId;
  bool _loading = false;
  bool _sessionOpen = false;

  // ── Scan Order ────────────────────────────
  Future<void> _scanOrder(String value) async {
    final orderId = value.trim().toUpperCase();
    if (orderId.isEmpty) return;

    setState(() => _loading = true);

    final result = await ApiService().getReturnOrder(orderId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ไม่พบ Order นี้ในระบบ',
      );
      _orderController.clear();
      _orderFocus.requestFocus();
      return;
    }

    setState(() => _order = result.data);
    await _openSession();
  }

  // ── Open Session ──────────────────────────
  Future<void> _openSession() async {
    if (_order == null) return;
    setState(() => _loading = true);

    final result = await ApiService().openReturnSession(
      orderId: _order!.orderId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ไม่สามารถเปิด session ได้',
      );
      return;
    }

    setState(() {
      _returnId = result.data!.returnId;
      _sessionOpen = true;
    });
  }

  // ── Receive Item ──────────────────────────
  Future<void> _receiveItem(OrderItemResponse item) async {
    if (_returnId == null) return;

    // แสดง bottom sheet รับจำนวนและหมายเหตุ
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReturnItemSheet(item: item),
    );

    if (res == null || !mounted) return;

    setState(() => _loading = true);

    final result = await ApiService().receiveReturnItem(
      returnId: _returnId!,
      orderId: _order!.orderId,
      partId: item.partId,
      qtyReturned: res['qty'] as int,
      note: res['note'] as String?,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'บันทึกไม่สำเร็จ');
      return;
    }

    showSuccessSnackbar(context, result.data!.message);

    // อัปเดต status ใน local list
    setState(() {
      final idx = _order!.items.indexWhere((i) => i.partId == item.partId);
      if (idx != -1) {
        _order!.items[idx] = _order!.items[idx].copyWith(status: 'RETURNED');
      }
    });
  }

  // ── Close Session ─────────────────────────
  Future<void> _closeSession() async {
    if (_returnId == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'ปิดการรับคืน',
      message: 'ยืนยันปิด session การรับสินค้าคืนใช่ไหม?',
      confirmLabel: 'ปิด Session',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await ApiService().closeReturnSession(_returnId!);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ปิด session ไม่สำเร็จ',
      );
      return;
    }

    final data = result.data!;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        title: const Text('รับสินค้าคืนเสร็จสิ้น'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.message),
            const SizedBox(height: 8),
            Text(
              'สถานะ Order: ${data.orderStatus}',
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับ Flow1Menu
            },
            child: const Text('เสร็จสิ้น'),
          ),
        ],
      ),
    );
  }

  // ── Reset ─────────────────────────────────
  void _reset() {
    setState(() {
      _order = null;
      _returnId = null;
      _sessionOpen = false;
      _orderController.clear();
    });
    _orderFocus.requestFocus();
  }

  @override
  void dispose() {
    _orderController.dispose();
    _orderFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        appBar: WmsAppBar(
          title: 'รับสินค้าคืน',
          userName: widget.fullName,
          actions: [
            if (_sessionOpen)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'สแกนใหม่',
                onPressed: _reset,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Scan Order ───────────────
                if (!_sessionOpen) ...[
                  Text(
                    'สแกน Order Number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ScanTextField(
                    controller: _orderController,
                    label: 'Order ID',
                    hint: 'เช่น ORD-001',
                    onSubmit: () => _scanOrder(_orderController.text),
                  ),
                ],

                // ── Order Info ───────────────
                if (_order != null) ...[
                  const SizedBox(height: 20),
                  WmsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              MdiIcons.fileDocumentOutline,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _order!.orderId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            StatusBadge(_order!.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InfoRow(label: 'ลูกค้า', value: _order!.customerName),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Items List ───────────
                  Text(
                    'รายการสินค้า',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._order!.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReturnItemCard(
                        item: item,
                        onReceive: _sessionOpen && item.status == 'ACTIVE'
                            ? () => _receiveItem(item)
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Close Button ─────────
                  if (_sessionOpen)
                    PrimaryButton(
                      label: 'ปิด Session รับคืน',
                      icon: Icons.check_circle,
                      onPressed: _closeSession,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================
// _ReturnItemCard
// =============================================
class _ReturnItemCard extends StatelessWidget {
  final OrderItemResponse item;
  final VoidCallback? onReceive;

  const _ReturnItemCard({required this.item, this.onReceive});

  @override
  Widget build(BuildContext context) {
    final isDone = item.status == 'RETURNED';

    return WmsCard(
      child: Row(
        children: [
          // Product thumbnail
          PartThumbnail(imageUrl: item.imageUrl, size: 40),
          const SizedBox(width: 10),
          // Status Icon
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? AppTheme.success : AppTheme.textGrey(context),
            size: 24,
          ),
          const SizedBox(width: 12),

          // Part Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.partId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  item.itemDesc,
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.owner} / ${item.brand}',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'จำนวนที่ซื้อ: ${item.qtySold} ชิ้น',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),

          // Action Button
          if (onReceive != null)
            TextButton(onPressed: onReceive, child: const Text('รับคืน'))
          else if (isDone)
            const StatusBadge('RETURNED'),
        ],
      ),
    );
  }
}

// =============================================
// _ReturnItemSheet — Bottom Sheet รับจำนวน
// =============================================
class _ReturnItemSheet extends StatefulWidget {
  final OrderItemResponse item;

  const _ReturnItemSheet({required this.item});

  @override
  State<_ReturnItemSheet> createState() => _ReturnItemSheetState();
}

class _ReturnItemSheetState extends State<_ReturnItemSheet> {
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirm() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      showErrorDialog(context, message: 'กรุณาระบุจำนวนที่ถูกต้อง');
      return;
    }
    Navigator.pop(context, {
      'qty': qty,
      'note': _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            widget.item.partId,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          Text(
            widget.item.itemDesc,
            style: TextStyle(color: AppTheme.textGrey(context)),
          ),
          Text(
            'ซื้อไป ${widget.item.qtySold} ชิ้น',
            style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Qty Input
          const Text(
            'จำนวนที่รับคืน',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'ระบุจำนวน',
              suffixText: 'ชิ้น',
            ),
          ),
          const SizedBox(height: 16),

          // Note Input
          const Text(
            'หมายเหตุ (ถ้ามี)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'เช่น สินค้าแตก / กล่องบุบ',
            ),
          ),
          const SizedBox(height: 24),

          // Confirm Button
          PrimaryButton(
            label: 'ยืนยันรับคืน',
            icon: Icons.check,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}
