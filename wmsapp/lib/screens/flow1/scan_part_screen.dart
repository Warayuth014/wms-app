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
  final _api = ApiService();

  DateTime? _selectedExpDate;

  // Part ที่สแกนได้แล้ว รอผูก pallet
  final List<ReceiptLineResponse> _scannedLines = [];

  String _condition = 'NORMAL';
  bool _loading = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Restore lines ที่รอผูก pallet จาก session ที่ resume มา
    if (widget.session.pendingLines.isNotEmpty) {
      _scannedLines.addAll(widget.session.pendingLines);
    }
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

                // Expired Date — date picker (พ.ศ.)
                GestureDetector(
                  onTap: () async {
                    final picked = await showModalBottomSheet<DateTime>(
                      context: ctx,
                      isScrollControlled: false,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _ThaiDatePicker(
                        initialDate: _selectedExpDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                      ),
                    );
                    if (picked != null) {
                      setModal(() => _selectedExpDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _selectedExpDate != null
                            ? AppTheme.primary
                            : const Color(0xFFE0E0E0),
                        width: _selectedExpDate != null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: _selectedExpDate != null
                              ? AppTheme.primary
                              : AppTheme.textGrey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedExpDate != null
                                ? '${_selectedExpDate!.day.toString().padLeft(2, '0')}/'
                                    '${_selectedExpDate!.month.toString().padLeft(2, '0')}/'
                                    '${_selectedExpDate!.year + 543}'
                                : 'Expired Date (ไม่บังคับ)',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedExpDate != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textGrey,
                            ),
                          ),
                        ),
                        if (_selectedExpDate != null)
                          GestureDetector(
                            onTap: () => setModal(() => _selectedExpDate = null),
                            child: const Icon(
                              Icons.clear,
                              color: AppTheme.textGrey,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
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
          'expiredDate': _selectedExpDate != null
              ? '${_selectedExpDate!.year}-'
                  '${_selectedExpDate!.month.toString().padLeft(2, '0')}-'
                  '${_selectedExpDate!.day.toString().padLeft(2, '0')}'
              : '',
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
        _selectedExpDate = null;
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
      expiredDate: _selectedExpDate != null
          ? '${_selectedExpDate!.year}-'
              '${_selectedExpDate!.month.toString().padLeft(2, '0')}-'
              '${_selectedExpDate!.day.toString().padLeft(2, '0')}'
          : null,
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
      showSuccessSnackbar(context, '${line.partId} บันทึกแล้ว');
    }

    setState(() {
      _scannedLines.add(line);
      _partController.clear();
      _qtyController.clear();
      _lotController.clear();
      _selectedExpDate = null;
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
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.3),
                ),
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

// ── Thai Buddhist Era Date Picker ─────────────
class _ThaiDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;

  const _ThaiDatePicker({
    required this.initialDate,
    required this.firstDate,
  });

  @override
  State<_ThaiDatePicker> createState() => _ThaiDatePickerState();
}

class _ThaiDatePickerState extends State<_ThaiDatePicker> {
  late int _day;
  late int _month;
  late int _year; // ปี ค.ศ. ใช้ภายใน

  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;

  static const _monthNames = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  int get _startYear => widget.firstDate.year;
  int get _endYear => 2099;
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.day;
    _month = widget.initialDate.month;
    _year = widget.initialDate.year;
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl = FixedExtentScrollController(
      initialItem: _year - _startYear,
    );
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final validDay = _day.clamp(1, _daysInMonth);
    Navigator.pop(context, DateTime(_year, _month, validDay));
  }

  @override
  Widget build(BuildContext context) {
    const itemH = 48.0;
    return Container(
      height: 340,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                ),
                const Text(
                  'เลือกวันหมดอายุ (พ.ศ.)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                TextButton(
                  onPressed: _confirm,
                  child: const Text(
                    'ตกลง',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // columns
          Expanded(
            child: Stack(
              children: [
                // selection highlight band
                Center(
                  child: IgnorePointer(
                    child: Container(
                      height: itemH,
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        color: AppTheme.primary.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // วัน
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _dayCtrl,
                        itemExtent: itemH,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _day = i + 1),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 31,
                          builder: (_, i) {
                            final day = i + 1;
                            final valid = day <= _daysInMonth;
                            return Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: day == _day
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: valid
                                      ? (day == _day
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary)
                                      : Colors.grey.shade300,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // เดือน
                    Expanded(
                      flex: 2,
                      child: ListWheelScrollView.useDelegate(
                        controller: _monthCtrl,
                        itemExtent: itemH,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _month = i + 1),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12,
                          builder: (_, i) => Center(
                            child: Text(
                              _monthNames[i],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: (i + 1) == _month
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: (i + 1) == _month
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ปี (พ.ศ.)
                    Expanded(
                      flex: 2,
                      child: ListWheelScrollView.useDelegate(
                        controller: _yearCtrl,
                        itemExtent: itemH,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) =>
                            setState(() => _year = _startYear + i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _endYear - _startYear + 1,
                          builder: (_, i) {
                            final ceYear = _startYear + i;
                            final beYear = ceYear + 543;
                            return Center(
                              child: Text(
                                '$beYear',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: ceYear == _year
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: ceYear == _year
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
