// lib/screens/test/test_pick_order_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';

class TestPickOrderScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const TestPickOrderScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<TestPickOrderScreen> createState() => _TestPickOrderScreenState();
}

class _TestPickOrderScreenState extends State<TestPickOrderScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _lines = [];

  // lineId → selected
  final Set<int> _selected = {};
  // lineId → qty controller
  final Map<int, TextEditingController> _qtyCtrl = {};

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLines() async {
    setState(() => _loading = true);
    final result = await _api.getAvailableLines();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่ได้');
      return;
    }

    setState(() {
      _lines = result.data!;
      _selected.clear();
      for (final c in _qtyCtrl.values) {
        c.dispose();
      }
      _qtyCtrl.clear();
      for (final line in _lines) {
        final lineId = line['lineId'] as int;
        final available = line['availableQty'] as int;
        _qtyCtrl[lineId] = TextEditingController(text: '$available');
      }
    });
  }

  Future<void> _createOrder() async {
    if (_selected.isEmpty) {
      showErrorDialog(context, message: 'กรุณาเลือกสินค้าอย่างน้อย 1 รายการ');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final lineId in _selected) {
      final line = _lines.firstWhere((l) => l['lineId'] == lineId);
      final qty = int.tryParse(_qtyCtrl[lineId]?.text.trim() ?? '') ?? 0;
      if (qty <= 0) {
        showErrorDialog(
          context,
          message: 'จำนวนต้องมากกว่า 0 (${line['partId']})',
        );
        return;
      }
      final available = line['availableQty'] as int;
      if (qty > available) {
        showErrorDialog(
          context,
          message: '${line['partId']} มีแค่ $available ชิ้น',
        );
        return;
      }
      items.add({'lineId': lineId, 'partId': line['partId'], 'qty': qty});
    }

    final confirm = await showConfirmDialog(
      context,
      title: 'สร้าง Pick Order',
      message: 'สร้าง Pick Order จาก ${items.length} รายการ?',
      confirmLabel: 'สร้าง',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);
    final result = await _api.createTestOrder(
      operatorId: widget.userId,
      items: items,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สร้างไม่สำเร็จ');
      return;
    }

    final orderId = result.data!['pickOrderId'] as String;
    showSuccessSnackbar(context, 'สร้าง $orderId สำเร็จ');
    await _loadLines(); // reload
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _lines.length) {
        _selected.clear();
      } else {
        _selected.addAll(_lines.map((l) => l['lineId'] as int));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'TEST Pick Order', userName: widget.fullName),
      body: LoadingOverlay(
        loading: _loading,
        message: 'กำลังโหลด...',
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.science, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'เลือกสินค้าที่ต้องการ Pick (${_selected.length}/${_lines.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _toggleAll,
                    child: Text(
                      _selected.length == _lines.length
                          ? 'Clear All'
                          : 'Select All',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadLines,
                  ),
                ],
              ),
            ),

            // ── List ──
            Expanded(
              child: _lines.isEmpty
                  ? Center(
                      child: Text(
                        'ไม่มีสินค้าที่ PALLETIZED\nหรือถูก allocate หมดแล้ว',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textGrey(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _lines.length,
                      itemBuilder: (_, i) => _buildLineItem(_lines[i]),
                    ),
            ),

            // ── Create Button ──
            if (_selected.isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PrimaryButton(
                    label: 'สร้าง Pick Order (${_selected.length} รายการ)',
                    icon: Icons.add_task,
                    onPressed: _createOrder,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(Map<String, dynamic> line) {
    final lineId = line['lineId'] as int;
    final selected = _selected.contains(lineId);
    final partId = line['partId'] as String;
    final itemDesc = line['itemDesc'] as String;
    final palletId = line['palletId'] as String;
    final palletType = line['palletType'] as String;
    final available = line['availableQty'] as int;
    final owner = line['owner'] as String;
    final condition = line['condition'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      color: selected ? AppTheme.primary.withValues(alpha: 0.03) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            selected ? _selected.remove(lineId) : _selected.add(lineId);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? AppTheme.primary : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(condition),
                      ],
                    ),
                    Text(
                      itemDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(Icons.inventory_2, palletId),
                        const SizedBox(width: 6),
                        _InfoChip(Icons.label, palletType),
                        const SizedBox(width: 6),
                        _InfoChip(Icons.person, owner),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Qty input
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _qtyCtrl[lineId],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  enabled: selected,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    suffixText: '/$available',
                    suffixStyle: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textGrey(context),
                    ),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textGrey(context)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }
}
