// lib/screens/flow2/replenish_order_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import 'replenish_work_screen.dart';

class ReplenishOrderScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const ReplenishOrderScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<ReplenishOrderScreen> createState() => _ReplenishOrderScreenState();
}

class _ReplenishOrderScreenState extends State<ReplenishOrderScreen> {
  final _api = ApiService();

  CheckTriggerResponse? _trigger;
  List<ReplenishOrderResponse> _orders = [];
  bool _loading = true;
  bool _creatingOrder = false;

  // เลือก Part จาก trigger ที่จะสร้าง order
  final Set<String> _selectedPartIds = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final triggerResult = await _api.checkReplenishTrigger();
    final ordersResult = await _api.getReplenishOrders();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (triggerResult.success) _trigger = triggerResult.data;
      if (ordersResult.success) _orders = ordersResult.data!;
    });
  }

  Future<void> _createOrder() async {
    if (_selectedPartIds.isEmpty) return;

    final triggerItems = _trigger!.items
        .where((t) => _selectedPartIds.contains(t.partId))
        .toList();

    final lines = triggerItems
        .map((t) => {'partId': t.partId, 'qtyRequired': t.qtyRequired})
        .toList();

    setState(() => _creatingOrder = true);
    final result = await _api.createReplenishOrder(
      triggeredBy: 'MANUAL',
      lines: lines,
    );
    setState(() => _creatingOrder = false);

    if (!mounted) return;
    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    _selectedPartIds.clear();
    showSuccessSnackbar(context, 'สร้าง Order #${result.data!.orderId} เรียบร้อย');
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Replenish Orders',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Trigger Banner ─────────────
                      if (_trigger != null &&
                          _trigger!.partsNeedingReplenishment > 0)
                        _buildTriggerBanner(),

                      const SizedBox(height: 20),

                      // ── Active Orders ──────────────
                      SectionHeader(
                        title: 'Orders ที่ค้างอยู่ (${_orders.length})',
                        icon: Icons.list_alt,
                      ),
                      const SizedBox(height: 12),

                      if (_orders.isEmpty)
                        _buildEmptyOrders()
                      else
                        for (final order in _orders) ...[
                          _buildOrderCard(order),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTriggerBanner() {
    final items = _trigger!.items;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'ต้องเติม ${items.length} รายการ',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.warning,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _selectedPartIds.length == items.length
                    ? () => setState(() => _selectedPartIds.clear())
                    : () => setState(
                        () => _selectedPartIds.addAll(items.map((e) => e.partId))),
                icon: Icon(
                  _selectedPartIds.length == items.length
                      ? Icons.deselect
                      : Icons.select_all,
                  size: 16,
                ),
                label: Text(
                  _selectedPartIds.length == items.length
                      ? 'ยกเลิกทั้งหมด'
                      : 'เลือกทั้งหมด',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items) _buildTriggerItem(item),
          const SizedBox(height: 12),
          LoadingOverlay(
            loading: _creatingOrder,
            message: 'กำลังสร้าง Order...',
            child: PrimaryButton(
              label: _selectedPartIds.isEmpty
                  ? 'เลือก Part เพื่อสร้าง Order'
                  : 'สร้าง Order (${_selectedPartIds.length} รายการ)',
              icon: Icons.add_task,
              onPressed: _selectedPartIds.isEmpty ? () {} : _createOrder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerItem(ReplenishTriggerItem item) {
    final selected = _selectedPartIds.contains(item.partId);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedPartIds.remove(item.partId);
        } else {
          _selectedPartIds.add(item.partId);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? AppTheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemDesc,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${item.partId} | On-hand: ${item.qtyOnHand} / Min: ${item.minStock}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${item.qtyRequired}',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(ReplenishOrderResponse order) {
    final doneCount = order.lines.where((l) => l.status == 'COMPLETED').length;
    final progress = order.lines.isEmpty ? 0.0 : doneCount / order.lines.length;
    final statusColor = order.status == 'IN_PROGRESS'
        ? AppTheme.warning
        : AppTheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReplenishWorkScreen(
              userId: widget.userId,
              fullName: widget.fullName,
              order: order,
            ),
          ),
        ).then((_) => _loadAll()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Order #${order.orderId}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(order.status),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.triggeredBy,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.success,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '$doneCount / ${order.lines.length} รายการเสร็จ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: order.lines
                    .map((l) => Chip(
                          label: Text(
                            l.partId,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: l.status == 'COMPLETED'
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return WmsCard(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              color: AppTheme.success, size: 48),
          const SizedBox(height: 8),
          const Text(
            'ไม่มี Order ค้างอยู่',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'ระบบจะแจ้งเมื่อสต็อกต่ำกว่า Minimum',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }
}
