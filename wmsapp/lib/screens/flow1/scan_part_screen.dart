// lib/screens/flow1/scan_part_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/offline_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/wms_models.dart';
import 'assign_pallet_screen.dart';

class ScanPartScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final ReceivingSession session;
  final POResponse po;

  const ScanPartScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.session,
    required this.po,
  });

  @override
  State<ScanPartScreen> createState() => _ScanPartScreenState();
}

class _ScanPartScreenState extends State<ScanPartScreen> {
  final _partController = TextEditingController();
  final _qtyController = TextEditingController();
  final _lotController = TextEditingController();
  final _expController = TextEditingController();
  final _api = ApiService();

  // Part ที่สแกนได้แล้ว รอผูก pallet
  final List<ReceiptLineResponse> _scannedLines = [];

  String _condition = 'NORMAL';
  bool _loading = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService().checkNow();
    setState(() => _isOnline = online);
  }

  // ── สแกน Part ────────────────────────────────
  Future<void> _scanPart() async {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Part ID');
      return;
    }

    // ตรวจว่าสแกนซ้ำไหม
    final alreadyScanned = _scannedLines.any((l) => l.partId == partId);
    if (alreadyScanned) {
      showErrorDialog(
        context,
        message: 'Part $partId สแกนไปแล้วใน session นี้',
      );
      return;
    }

    // ตรวจว่า Part อยู่ใน PO ไหม
    final inPO = widget.po.items.any((i) => i.partId == partId);
    if (!inPO) {
      showErrorDialog(
        context,
        message: 'Part $partId ไม่อยู่ใน PO ${widget.po.poId}',
      );
      return;
    }

    // โชว์ form กรอกข้อมูล
    final poItem = widget.po.items.firstWhere((i) => i.partId == partId);

    setState(() {
      _qtyController.text = poItem.qtyOrdered.toString();
    });

    _showPartForm(poItem);
  }

  // ── Form กรอก qty, lot, expired ──────────────
  void _showPartForm(POItem poItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      poItem.partId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  poItem.itemDesc,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
                const Divider(height: 20),

                // ข้อมูล Part
                InfoRow(
                  label: 'Owner',
                  value: '${poItem.owner} (${poItem.brand})',
                ),
                InfoRow(label: 'ต้องรับ', value: '${poItem.qtyOrdered} ชิ้น'),
                const SizedBox(height: 16),

                // Qty
                TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนที่รับจริง',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 12),

                // Lot
                TextField(
                  controller: _lotController,
                  decoration: const InputDecoration(
                    labelText: 'Lot Number',
                    prefixIcon: Icon(Icons.tag),
                    hintText: 'เช่น L001',
                  ),
                ),
                const SizedBox(height: 12),

                // Expired Date
                TextField(
                  controller: _expController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Expired Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    hintText: 'เช่น 2026-12-31',
                  ),
                ),
                const SizedBox(height: 12),

                // Condition
                const Text(
                  'สภาพสินค้า',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ConditionButton(
                        label: 'NORMAL',
                        icon: Icons.check_circle,
                        color: AppTheme.success,
                        selected: _condition == 'NORMAL',
                        onTap: () => setModal(() => _condition = 'NORMAL'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ConditionButton(
                        label: 'DAMAGED',
                        icon: Icons.warning,
                        color: AppTheme.danger,
                        selected: _condition == 'DAMAGED',
                        onTap: () => setModal(() => _condition = 'DAMAGED'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Confirm
                PrimaryButton(
                  label: 'บันทึก',
                  icon: Icons.save,
                  loading: _loading,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _confirmPart(poItem);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Confirm Part ──────────────────────────────
  Future<void> _confirmPart(POItem poItem) async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      showErrorDialog(context, message: 'จำนวนไม่ถูกต้อง');
      return;
    }

    setState(() => _loading = true);

    // ถ้า offline → บันทึกลง queue
    if (!_isOnline) {
      await OfflineService().addToQueue(
        action: 'scan-part',
        data: {
          'sessionId': widget.session.sessionId,
          'poId': widget.po.poId,
          'partId': poItem.partId,
          'qtyReceived': qty,
          'lotNumber': _lotController.text.trim(),
          'expiredDate': _expController.text.trim(),
          'condition': _condition,
          'operatorId': widget.userId,
        },
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _scannedLines.add(
          ReceiptLineResponse(
            lineId: -1, // temp
            partId: poItem.partId,
            owner: poItem.owner,
            brand: poItem.brand,
            itemDesc: poItem.itemDesc,
            qtyOrdered: poItem.qtyOrdered,
            qtyReceived: qty,
            condition: _condition,
            poItemStatus: 'PENDING',
            message: '⚠️ บันทึกแบบ offline',
          ),
        );
        _partController.clear();
        _qtyController.clear();
        _lotController.clear();
        _expController.clear();
        _condition = 'NORMAL';
      });

      showWarningSnackbar(
        context,
        'บันทึกแบบ offline จะ sync เมื่อ WiFi กลับมา',
      );
      return;
    }

    // online → ยิง API
    final result = await _api.scanReceiptPart(
      sessionId: widget.session.sessionId,
      poId: widget.po.poId,
      partId: poItem.partId,
      qtyReceived: qty,
      lotNumber: _lotController.text.trim().isEmpty
          ? null
          : _lotController.text.trim(),
      expiredDate: _expController.text.trim().isEmpty
          ? null
          : _expController.text.trim(),
      condition: _condition,
      operatorId: widget.userId,
    );

    setState(() => _loading = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    final line = result.data!;

    // แจ้งเตือน over receiving
    if (line.poItemStatus == 'OVER') {
      showWarningSnackbar(context, '⚠️ Over receiving: ${line.message}');
    } else {
      showSuccessSnackbar(context, '✅ ${line.partId} บันทึกแล้ว');
    }

    setState(() {
      _scannedLines.add(line);
      _partController.clear();
      _qtyController.clear();
      _lotController.clear();
      _expController.clear();
      _condition = 'NORMAL';
    });
  }

  // ── ไป assign_pallet ─────────────────────────
  void _goToAssignPallet() {
    if (_scannedLines.isEmpty) {
      showErrorDialog(
        context,
        message: 'กรุณาสแกน Part อย่างน้อย 1 รายการก่อน',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignPalletScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          session: widget.session,
          po: widget.po,
          scannedLines: _scannedLines,
          onAssigned: (assignedLineIds) {
            setState(() {
              _scannedLines.removeWhere(
                (l) => assignedLineIds.contains(l.lineId),
              );
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Part ที่ยังไม่ได้รับใน PO
    final pendingItems = widget.po.items
        .where((i) => i.status != 'RECEIVED')
        .toList();

    return Scaffold(
      appBar: WmsAppBar(title: 'สแกน Part', userName: widget.fullName),
      body: Column(
        children: [
          if (!_isOnline) const OfflineBanner(pendingCount: 0),

          Expanded(
            child: LoadingOverlay(
              loading: _loading,
              message: 'กำลังบันทึก...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Step Indicator ──────────
                    _buildStepIndicator(),
                    const SizedBox(height: 16),

                    // ── Session Info ────────────
                    WmsCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.po.poId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  widget.po.supplierName,
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Session #${widget.session.sessionId}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Scan Part ───────────────
                    WmsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'สแกน Part',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ScanTextField(
                            label: 'Part ID',
                            hint: 'เช่น PT-9821',
                            controller: _partController,
                            onSubmit: _scanPart,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'สแกน',
                            icon: Icons.qr_code_scanner,
                            onPressed: _scanPart,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── รายการที่สแกนแล้ว ───────
                    if (_scannedLines.isNotEmpty) ...[
                      _buildScannedList(),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label:
                            'สแกน Pallet'
                            ' (${_scannedLines.length} รายการ)',
                        icon: Icons.inventory_2,
                        onPressed: _goToAssignPallet,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── รายการที่ยังไม่สแกน ──────
                    if (pendingItems.isNotEmpty)
                      _buildPendingList(pendingItems),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scanned Lines ────────────────────────────
  Widget _buildScannedList() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'รอผูก Pallet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_scannedLines.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._scannedLines.map(
            (line) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          line.itemDesc,
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${line.qtyReceived} ชิ้น',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      StatusBadge(line.condition),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pending Items ────────────────────────────
  Widget _buildPendingList(List<POItem> items) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยังไม่ได้สแกน',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.partId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          item.itemDesc,
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.qtyOrdered} ชิ้น',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepDot(number: 1, label: 'สแกน PO', done: true),
        _StepLine(),
        _StepDot(number: 2, label: 'สแกน Part', active: true),
        _StepLine(),
        _StepDot(number: 3, label: 'สแกน Pallet', active: false),
      ],
    );
  }
}

// ── Condition Button ──────────────────────────
class _ConditionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppTheme.background,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Widgets ──────────────────────────────
class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool done;

  const _StepDot({
    required this.number,
    required this.label,
    this.active = false,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppTheme.success
        : active
        ? AppTheme.primary
        : Colors.grey.shade300;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: active || done ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active || done ? AppTheme.primary : Colors.grey,
            fontWeight: active || done ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: Colors.grey.shade300,
      ),
    );
  }
}
