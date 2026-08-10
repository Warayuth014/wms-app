// lib/screens/receiving/scan_part/scan_part_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import 'ui_models/assigned_receiving_line.dart';
import 'widgets/lists/assigned_list.dart';
import 'widgets/bars/current_pallet_bar.dart';
import 'widgets/scan/pallet_scan_section.dart';
import 'widgets/lists/pending_items_list.dart';
import 'widgets/bars/receiving_session_bar.dart';
import 'widgets/lists/resumed_pending_list.dart';

class ScanPartScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final POResponse po;

  const ScanPartScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.po,
  });

  @override
  State<ScanPartScreen> createState() => _ScanPartScreenState();
}

enum _ScanStatusTone { success, duplicate }

class _ScanPartScreenState extends State<ScanPartScreen> {
  static const double _serialHeaderHeight = 32;
  static const double _serialRowHeight = 42;
  static const int _serialVisibleRowLimit = 5;

  final _partController = TextEditingController();
  final _partFocus = FocusNode();
  final _qtyController = TextEditingController();
  final _manualQtyController = TextEditingController(text: '0');
  final _serialController = TextEditingController();
  final _serialFocus = FocusNode();
  final _palletController = TextEditingController();
  final _palletFocus = FocusNode();
  final _serialListController = ScrollController();
  final _api = ApiService();

  bool _loading = false;
  late POResponse _currentPo;

  String? _lastPalletId;
  String? _lastPalletType;
  ReceiptLineResponse? _pendingLine;

  final List<AssignedReceivingLine> _assignedLines = [];
  final List<ReceiptLineResponse> _resumedPendingLines = [];
  final List<String> _serialNumbers = [];
  String? _serialPartId;
  POItem? _scanningItem;
  int _manualQty = 0;
  String? _highlightedSerial;
  bool _highlightedSerialDuplicate = false;
  Timer? _scanStatusTimer;
  String? _scanStatusMessage;
  _ScanStatusTone _scanStatusTone = _ScanStatusTone.success;

  @override
  void initState() {
    super.initState();
    _currentPo = widget.po;
    if (widget.po.pendingLines.isNotEmpty) {
      _resumedPendingLines.addAll(widget.po.pendingLines);
    }
  }

  Future<void> _reloadPo() async {
    final result = await _api.getPO(_currentPo.poId);
    if (mounted && result.success) {
      setState(() => _currentPo = result.data!);
    }
  }

  void _clearPalletMemoryForRetry(ReceiptLineResponse line) {
    setState(() {
      _pendingLine = line;
      _lastPalletId = null;
      _lastPalletType = null;
    });
  }

  void _storeAssignedLine(ReceiptLineResponse line, String palletId) {
    final existIdx = _assignedLines.indexWhere(
      (assigned) =>
          assigned.partId == line.partId && assigned.palletId == palletId,
    );

    if (existIdx >= 0) {
      final current = _assignedLines[existIdx];
      _assignedLines[existIdx] = current.copyWith(
        qtyReceived: current.qtyReceived + line.qtyReceived,
      );
      return;
    }

    _assignedLines.add(
      AssignedReceivingLine(
        partId: line.partId,
        itemDesc: line.itemDesc,
        qtyReceived: line.qtyReceived,
        condition: line.condition,
        palletId: palletId,
      ),
    );
  }

  void _clearSerialScan() {
    _serialPartId = null;
    _scanningItem = null;
    _manualQty = 0;
    _manualQtyController.text = '0';
    _highlightedSerial = null;
    _highlightedSerialDuplicate = false;
    _serialController.clear();
    _serialNumbers.clear();
    if (_serialListController.hasClients) {
      _serialListController.jumpTo(0);
    }
  }

  void _markScannedSerial(String serialNo, {bool duplicate = false}) {
    setState(() {
      _highlightedSerial = serialNo;
      _highlightedSerialDuplicate = duplicate;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _serialNumbers.indexOf(serialNo);
      if (index < 0 || !_serialListController.hasClients) return;

      final target = (index * _serialRowHeight)
          .clamp(0.0, _serialListController.position.maxScrollExtent)
          .toDouble();
      _serialListController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showScanStatus(
    String message, {
    _ScanStatusTone tone = _ScanStatusTone.success,
  }) {
    _scanStatusTimer?.cancel();
    setState(() {
      _scanStatusMessage = message;
      _scanStatusTone = tone;
    });
    _scanStatusTimer = Timer(const Duration(seconds: 5), _hideScanStatus);
  }

  void _holdScanStatus() {
    _scanStatusTimer?.cancel();
    _scanStatusTimer = null;
  }

  void _hideScanStatus() {
    _scanStatusTimer?.cancel();
    _scanStatusTimer = null;
    if (!mounted || _scanStatusMessage == null) return;
    setState(() => _scanStatusMessage = null);
  }

  // สแกน Part ID ก่อนเสมอ — เช็คว่ามีกี่ condition/lot แล้ว popup ให้เลือกถ้าจำเป็น
  Future<void> _scanPartId() async {
    if (_scanningItem != null) return;

    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Part ID');
      _partFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);
    final result = await _api.getPartLines(partId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'Part $partId ไม่อยู่ใน PO ${_currentPo.poId}',
      );
      _partFocus.requestFocus();
      return;
    }

    final relevantLines = result.data!.lines
        .where((l) => l.poId == _currentPo.poId)
        .toList();
    if (relevantLines.isEmpty) {
      showErrorDialog(
        context,
        message: 'Part $partId ไม่อยู่ใน PO ${_currentPo.poId}',
      );
      _partFocus.requestFocus();
      return;
    }

    PartLine line;
    if (relevantLines.length == 1) {
      line = relevantLines.first;
    } else {
      final chosen = await _pickCondition(relevantLines);
      if (!mounted || chosen == null) return;
      line = chosen;
    }

    if (line.lots.isEmpty) {
      showErrorDialog(
        context,
        message: 'Part $partId ไม่มี Lot ให้รับใน PO นี้',
      );
      return;
    }

    PartLot lot;
    if (line.lots.length == 1) {
      lot = line.lots.first;
    } else {
      final chosen = await _pickLot(line.lots);
      if (!mounted || chosen == null) return;
      lot = chosen;
    }

    final resolvedItem = _currentPo.items.firstWhere(
      (i) => i.id == lot.id,
      orElse: () => POItem(
        id: lot.id,
        partId: partId,
        owner: '',
        brand: '',
        itemDesc: '',
        serialRequire: result.data!.serialRequire,
        qtyOrdered: lot.qtyOrdered,
        qtyReceived: lot.qtyReceived,
        qtyRemaining: lot.qtyOrdered - lot.qtyReceived,
        status: 'PENDING',
        condition: line.condition,
        lotNumber: lot.lotNumber,
      ),
    );

    setState(() {
      _scanningItem = resolvedItem;
      _serialPartId = partId;
      _manualQty = 0;
      _manualQtyController.text = '0';
    });

    if (resolvedItem.serialRequire) {
      _serialFocus.requestFocus();
    }
  }

  Color _conditionColor(String condition) =>
      condition == 'FG' ? AppTheme.success : AppTheme.warning;

  Widget _buildConditionCard({
    required BuildContext ctx,
    required String condition,
    required int lotCount,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = _conditionColor(condition);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: selected ? 2.5 : 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                condition,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              condition,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            // Text(
            //   '$lotCount lot',
            //   style: TextStyle(fontSize: 13, color: AppTheme.textGrey(ctx)),
            // ),
            const SizedBox(height: 10),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right, color: color, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<PartLine?> _pickCondition(List<PartLine> lines) {
    PartLine? selected;

    return showModalBottomSheet<PartLine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เลือกประเภทสินค้าที่จะรับ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'กรุณาเลือกประเภทสินค้าเพื่อดูจำนวน Lot ที่จะรับ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey(ctx)),
              ),
              const SizedBox(height: 16),
              Row(
                children: lines
                    .map(
                      (line) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildConditionCard(
                            ctx: ctx,
                            condition: line.condition,
                            lotCount: line.lots.length,
                            selected: selected == line,
                            onTap: () => setModalState(() => selected = line),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'ยืนยันการเลือก',
                  onPressed: selected != null
                      ? () => Navigator.pop(ctx, selected)
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLotRow({
    required BuildContext ctx,
    required PartLot lot,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final available = lot.qtyOrdered - lot.qtyReceived;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : Colors.grey.withValues(alpha: 0.25),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            // Container(
            //   width: 40,
            //   height: 40,
            //   decoration: BoxDecoration(
            //     color: AppTheme.primary.withValues(alpha: 0.08),
            //     shape: BoxShape.circle,
            //   ),
            //   child: Icon(
            //     MdiIcons.tagOutline,
            //     color: AppTheme.primary,
            //     size: 20,
            //   ),
            // ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.lotNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Batch No. ${lot.lotNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey(ctx),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'รับได้ $available ชิ้น',
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? AppTheme.primary : AppTheme.textGrey(ctx),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppTheme.primary : Colors.grey.shade400,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<PartLot?> _pickLot(List<PartLot> lots) {
    PartLot? selected;

    return showModalBottomSheet<PartLot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      MdiIcons.tagOutline,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'เลือก Lot ที่จะรับ',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'เลือกรายการ Lot เพื่อดำเนินการรับสินค้า',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textGrey(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: lots
                        .map(
                          (lot) => _buildLotRow(
                            ctx: ctx,
                            lot: lot,
                            selected: selected == lot,
                            onTap: () => setModalState(() => selected = lot),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'ยืนยันการเลือก',
                  icon: Icons.check_circle,
                  onPressed: selected != null
                      ? () => Navigator.pop(ctx, selected)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // เพิ่ม S/N ให้ item ที่ resolve ไว้แล้วจาก _scanPartId
  Future<void> _addSerial() async {
    final item = _scanningItem;
    if (item == null) {
      showErrorDialog(context, message: 'กรุณาสแกน Part ID ก่อน');
      _partFocus.requestFocus();
      return;
    }

    final serialNo = _serialController.text.trim().toUpperCase();
    if (serialNo.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ S/N');
      _serialFocus.requestFocus();
      return;
    }

    final existingSerialIndex = _serialNumbers.indexOf(serialNo);
    if (existingSerialIndex >= 0) {
      _markScannedSerial(serialNo, duplicate: true);
      _showScanStatus(
        'S/N "$serialNo" สแกนแล้ว อยู่รายการที่ ${existingSerialIndex + 1}',
        tone: _ScanStatusTone.duplicate,
      );
      _serialController.clear();
      _serialFocus.requestFocus();
      return;
    }

    final maxQty = item.qtyRemaining > 0 ? item.qtyRemaining : item.qtyOrdered;
    if (_serialNumbers.length >= maxQty) {
      showErrorDialog(context, message: 'สแกนครบ $maxQty ชิ้นแล้ว');
      _serialController.clear();
      _serialFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);
    final serialResult = await _api.validateReceivingSerial(
      partId: item.partId,
      serialNo: serialNo,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!serialResult.success) {
      showErrorDialog(context, message: serialResult.error ?? 'S/N ไม่ถูกต้อง');
      _serialFocus.requestFocus();
      return;
    }

    // S/N ต้องเป็นของ lot/line ที่กำลังรับอยู่เท่านั้น (กันสแกน S/N lot อื่นหลุดเข้ามาผิด lot)
    if (serialResult.data!.lineId != item.id) {
      showErrorDialog(
        context,
        message:
            'S/N "$serialNo" ไม่ตรงกับ Lot "${item.lotNumber}" ที่กำลังรับ '
            '(จริงๆ อยู่ Lot "${serialResult.data!.lotNumber ?? "ไม่ทราบ"}")',
      );
      _serialController.clear();
      _serialFocus.requestFocus();
      return;
    }

    setState(() {
      _serialNumbers.add(serialNo);
      _qtyController.text = _serialNumbers.length.toString();
      _serialController.clear();
    });
    _markScannedSerial(serialNo);
    _showScanStatus(
      'เพิ่ม S/N "$serialNo" แล้ว อยู่รายการที่ ${_serialNumbers.length}',
    );
    _serialFocus.requestFocus();
  }

  void showPartForm(POItem poItem) {
    final condColor = poItem.condition == 'FG'
        ? AppTheme.success
        : AppTheme.warning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        poItem.partId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
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
                  style: TextStyle(color: AppTheme.textGrey(ctx), fontSize: 13),
                ),
                const Divider(height: 20),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: condColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: condColor, width: 2),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        poItem.condition == 'FG'
                            ? Icons.check_circle
                            : MdiIcons.cogOutline,
                        color: condColor,
                        size: 36,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        poItem.condition,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: condColor,
                        ),
                      ),
                      Text(
                        poItem.condition == 'FG'
                            ? 'สินค้าปกติ'
                            : 'ต้องติดสติ๊กเกอร์',
                        style: TextStyle(fontSize: 13, color: condColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoRow(
                  label: 'Owner',
                  value: '${poItem.owner} (${poItem.brand})',
                ),
                InfoRow(label: 'สั่งซื้อ', value: '${poItem.qtyOrdered} ชิ้น'),
                if (poItem.qtyRemaining > 0 &&
                    poItem.qtyRemaining < poItem.qtyOrdered)
                  InfoRow(
                    label: 'รับได้อีก',
                    value: '${poItem.qtyRemaining} ชิ้น',
                    valueColor: AppTheme.warning,
                  ),
                if (poItem.lotNumber != null && poItem.lotNumber!.isNotEmpty)
                  InfoRow(label: 'Batch No.', value: poItem.lotNumber!),
                if (poItem.expiredDate != null &&
                    poItem.expiredDate!.isNotEmpty)
                  InfoRow(label: 'Exp', value: poItem.expiredDate!),
                const SizedBox(height: 16),
                TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'จำนวนที่รับจริง',
                    prefixIcon: Icon(MdiIcons.numeric),
                  ),
                ),
                const SizedBox(height: 8),
                InfoRow(
                  label: 'S/N',
                  value: _serialNumbers.isNotEmpty ? _serialNumbers.first : '-',
                  valueColor: AppTheme.primary,
                  bold: true,
                ),
                const SizedBox(height: 16),
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

  Future<void> _confirmPart(POItem poItem, {int? qtyOverride}) async {
    final qty = qtyOverride ?? int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      showErrorDialog(context, message: 'จำนวนไม่ถูกต้อง');
      return;
    }

    final maxQty = poItem.qtyRemaining > 0
        ? poItem.qtyRemaining
        : poItem.qtyOrdered;
    if (qty > maxQty) {
      showErrorDialog(
        context,
        message:
            'รับได้สูงสุด $maxQty ชิ้น (รับไปแล้ว ${poItem.qtyReceived} ชิ้น)',
      );
      return;
    }

    // สินค้ามี serial ต้องมี S/N ครบตามจำนวน — ไม่มี serial ก็รับจำนวนตรงๆ ได้เลย
    List<String>? serialNumbers;
    if (poItem.serialRequire) {
      serialNumbers =
          _serialPartId == poItem.partId && _serialNumbers.length == qty
          ? List<String>.of(_serialNumbers)
          : null;
      if (serialNumbers == null) {
        showErrorDialog(
          context,
          message: _serialNumbers.isEmpty
              ? 'กรุณาสแกน S/N'
              : 'จำนวน S/N (${_serialNumbers.length}) ไม่ตรงกับจำนวนรับ ($qty)',
        );
        return;
      }
    }

    // เด้ง popup สแกน pallet ก่อนบันทึกจริงเสมอ (ไม่ต้องไปหน้าอื่น/section อื่น)
    final palletId = await _pickPallet(defaultPalletId: _lastPalletId);
    if (!mounted || palletId == null || palletId.isEmpty) return;

    setState(() => _loading = true);

    final result = await _api.scanReceiptPart(
      poId: widget.po.poId,
      partId: poItem.partId,
      lineId: poItem.id,
      qtyReceived: qty,
      operatorId: widget.userId,
      serialNumbers: serialNumbers,
      palletId: palletId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    final line = result.data!;

    if (line.poItemStatus == 'OVER') {
      showWarningSnackbar(context, 'Over receiving: ${line.message}');
    }

    if (line.palletError != null) {
      // scan สำเร็จแล้ว แค่ผูก pallet ไม่สำเร็จ — เอาไปไว้ในลิสต์รอผูกใหม่
      showWarningSnackbar(
        context,
        '${line.partId} บันทึกแล้ว แต่ผูก Pallet ไม่สำเร็จ: ${line.palletError}',
      );
      setState(() => _resumedPendingLines.insert(0, line));
    } else {
      showSuccessSnackbar(context, '${line.partId} -> Pallet ${line.palletId} สำเร็จ');
      setState(() {
        _lastPalletId = line.palletId;
        _lastPalletType = line.condition;
        _storeAssignedLine(line, line.palletId!);
      });
    }

    _clearFormFields();
    _clearSerialScan();

    if (line.autoClosed) {
      await _showAutoClosedDialog(
        line.poStatus ?? 'RECEIVED',
        line.closeMessage ?? 'ปิด Session อัตโนมัติ',
      );
      return;
    }

    await _reloadPo();
    _partFocus.requestFocus();
  }

  // สแกน/กรอก Pallet ID ก่อน submit จริง — popup ลอย ไม่สลับ section/หน้า
  Future<String?> _pickPallet({String? defaultPalletId}) {
    final controller = TextEditingController(text: defaultPalletId ?? '');
    final focusNode = FocusNode();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'สแกน Pallet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'สแกนหรือกรอก Pallet ID เพื่อใส่สินค้าที่รับเข้า',
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey(ctx)),
              ),
              const SizedBox(height: 16),
              ScanTextField(
                label: 'Pallet ID',
                hint: 'เช่น PLT-001',
                controller: controller,
                focusNode: focusNode,
                onSubmit: () {
                  final id = controller.text.trim().toUpperCase();
                  if (id.isNotEmpty) Navigator.pop(ctx, id);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'ยืนยัน',
                  icon: Icons.save,
                  onPressed: () {
                    final id = controller.text.trim().toUpperCase();
                    if (id.isEmpty) return;
                    Navigator.pop(ctx, id);
                  },
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAutoClosedDialog(String poStatus, String closeMessage) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              poStatus == 'RECEIVED' ? Icons.check_circle : Icons.warning_amber,
              color: poStatus == 'RECEIVED' ? AppTheme.success : AppTheme.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                poStatus == 'RECEIVED' ? 'รับสินค้าครบแล้ว' : 'รับสินค้าบางส่วน',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(closeMessage),
            const SizedBox(height: 8),
            Text(
              'Session ถูกปิดอัตโนมัติ',
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
            ),
            const SizedBox(height: 12),
            InfoRow(label: 'PO', value: widget.po.poId),
            InfoRow(label: 'Status', value: poStatus),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(
                context,
                (route) => route.isFirst || route.settings.name == '/',
              );
            },
            child: const Text('เสร็จสิ้น'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignToPallet(
    ReceiptLineResponse line,
    String palletId,
  ) async {
    setState(() => _loading = true);

    final result = await _api.assignPallet(
      palletId: palletId,
      palletType: line.condition,
      operatorId: widget.userId,
      lineIds: [line.lineId],
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      _clearPalletMemoryForRetry(line);
      showErrorDialog(context, message: result.error ?? 'ผูก Pallet ไม่สำเร็จ');
      _palletFocus.requestFocus();
      return;
    }

    final data = result.data!;
    final autoClosed = data['autoClosed'] == true;

    setState(() {
      _lastPalletId = palletId;
      _lastPalletType = line.condition;
      _pendingLine = null;
      _storeAssignedLine(line, palletId);
    });

    showSuccessSnackbar(context, '${line.partId} -> Pallet $palletId สำเร็จ');

    if (autoClosed) {
      final poStatus = data['poStatus'] as String? ?? 'RECEIVED';
      final closeMessage =
          data['closeMessage'] as String? ?? 'ปิด Session อัตโนมัติ';

      if (!mounted) return;
      await _showAutoClosedDialog(poStatus, closeMessage);
      return;
    }

    await _reloadPo();
    _partFocus.requestFocus();
  }

  Future<void> _scanPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      return;
    }
    if (_pendingLine == null) return;

    await _assignToPallet(_pendingLine!, palletId);
    _palletController.clear();
  }

  Future<void> _assignResumedLine(ReceiptLineResponse line) async {
    if (_lastPalletId != null && _lastPalletType == line.condition) {
      await _assignToPallet(line, _lastPalletId!);
      setState(() => _resumedPendingLines.remove(line));
      return;
    }

    setState(() {
      _pendingLine = line;
      _resumedPendingLines.remove(line);
    });
    _palletFocus.requestFocus();
  }

  Future<void> _saveScannedSerials() async {
    final item = _scanningItem;
    if (item == null || _serialNumbers.isEmpty) {
      showErrorDialog(context, message: 'กรุณาสแกน Part และ S/N ก่อน');
      _serialFocus.requestFocus();
      return;
    }

    _qtyController.text = _serialNumbers.length.toString();
    await _confirmPart(item);
  }

  void _removeScannedSerial(String serialNo) {
    setState(() {
      _serialNumbers.remove(serialNo);
      if (_highlightedSerial == serialNo) {
        _highlightedSerial = null;
        _highlightedSerialDuplicate = false;
      }
      _qtyController.text = _serialNumbers.length.toString();
      if (_serialNumbers.isEmpty) {
        _clearSerialScan();
      }
    });
    _serialFocus.requestFocus();
  }

  Future<bool> _confirmRemoveScannedSerial(String serialNo) async {
    final index = _serialNumbers.indexOf(serialNo);
    final positionText = index >= 0 ? 'รายการที่ ${index + 1}' : 'รายการนี้';
    final confirmed = await showConfirmDialog(
      context,
      title: 'ลบ S/N?',
      message:
          'ต้องการลบ S/N "$serialNo" ($positionText) ออกจากรายการสแกนหรือไม่',
      confirmLabel: 'ลบ',
      cancelLabel: 'ยกเลิก',
      isDanger: true,
    );
    if (mounted) {
      _serialFocus.requestFocus();
    }
    return mounted && confirmed;
  }

  Future<void> _requestRemoveScannedSerial(String serialNo) async {
    final confirmed = await _confirmRemoveScannedSerial(serialNo);
    if (!confirmed) return;
    _removeScannedSerial(serialNo);
  }

  void _clearFormFields() {
    _partController.clear();
    _qtyController.clear();
  }

  Widget _buildSerialTable() {
    final visibleRows = _serialNumbers.length > _serialVisibleRowLimit
        ? _serialVisibleRowLimit
        : _serialNumbers.length;
    final rowCount = visibleRows == 0 ? 1 : visibleRows;

    return Container(
      height: _serialHeaderHeight + (rowCount * _serialRowHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: _serialHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: AppTheme.primary.withValues(alpha: 0.06),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'S/N',
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _serialListController,
              padding: EdgeInsets.zero,
              itemExtent: _serialRowHeight,
              itemCount: _serialNumbers.length,
              itemBuilder: (context, index) {
                final serialNo = _serialNumbers[index];
                final highlighted = serialNo == _highlightedSerial;
                final highlightColor = _highlightedSerialDuplicate
                    ? AppTheme.warning
                    : AppTheme.success;

                return Dismissible(
                  key: ValueKey('serial-$serialNo'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmRemoveScannedSerial(serialNo),
                  background: Container(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 14),
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.danger,
                      size: 22,
                    ),
                  ),
                  onDismissed: (_) => _removeScannedSerial(serialNo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: highlighted
                          ? highlightColor.withValues(alpha: 0.16)
                          : Colors.white,
                      border: Border(
                        left: BorderSide(
                          color: highlighted
                              ? highlightColor
                              : Colors.transparent,
                          width: 3,
                        ),
                        bottom: BorderSide(
                          color: AppTheme.textGrey(
                            context,
                          ).withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: highlighted
                                  ? highlightColor
                                  : AppTheme.textGrey(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            serialNo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: highlighted
                                  ? highlightColor
                                  : AppTheme.textPrimary(context),
                              fontSize: 12.5,
                              fontWeight: highlighted
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: _serialRowHeight,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: _serialRowHeight,
                            ),
                            iconSize: 20,
                            tooltip: 'ลบ S/N',
                            onPressed: () {
                              _requestRemoveScannedSerial(serialNo);
                            },
                            icon: Icon(
                              Icons.close,
                              color: AppTheme.textGrey(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedSerialSummary(POItem item) {
    final maxQty = item.qtyRemaining > 0 ? item.qtyRemaining : item.qtyOrdered;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.partId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              StatusBadge(item.condition),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.itemDesc,
            style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
          ),
          const SizedBox(height: 10),
          InfoRow(
            label: 'จำนวน',
            value: '${_serialNumbers.length} / $maxQty ชิ้น',
            valueColor: AppTheme.primary,
            bold: true,
          ),
          if (item.lotNumber != null && item.lotNumber!.isNotEmpty)
            InfoRow(label: 'Batch No.', value: item.lotNumber!),
          const SizedBox(height: 8),
          _buildSerialTable(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(_clearSerialScan),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('ล้าง'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveScannedSerials,
                  icon: const Icon(Icons.save, size: 18),
                  label: Text('บันทึก (${_serialNumbers.length})'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // สินค้าไม่มี serial — แก้จำนวนรับด้วยปุ่ม +/- แทนการสแกน S/N ทีละชิ้น
  void _setManualQty(int value, int maxQty) {
    final clamped = value.clamp(0, maxQty);
    final text = '$clamped';
    setState(() {
      _manualQty = clamped;
      if (_manualQtyController.text != text) {
        _manualQtyController.text = text;
        _manualQtyController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
    });
  }

  Widget _buildManualQtyEditor(POItem item) {
    final maxQty = item.qtyRemaining > 0 ? item.qtyRemaining : item.qtyOrdered;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.partId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              StatusBadge(item.condition),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.itemDesc,
            style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
          ),
          if (item.lotNumber != null && item.lotNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoRow(label: 'Batch No.', value: item.lotNumber!),
          ],
          const SizedBox(height: 12),
          Text(
            'จำนวนที่รับ',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _manualQty > 0
                    ? () => _setManualQty(_manualQty - 1, maxQty)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _manualQtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (value) =>
                      _setManualQty(int.tryParse(value) ?? 0, maxQty),
                ),
              ),
              IconButton.filled(
                onPressed: _manualQty < maxQty
                    ? () => _setManualQty(_manualQty + 1, maxQty)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Center(
            child: Text(
              'สูงสุด $maxQty ชิ้น',
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _clearSerialScan();
                    _clearFormFields();
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('ยกเลิก'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _manualQty > 0
                      ? () => _confirmPart(item, qtyOverride: _manualQty)
                      : null,
                  icon: const Icon(Icons.save, size: 18),
                  label: Text('บันทึก ($_manualQty)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingScanStatus() {
    final message = _scanStatusMessage;
    if (message == null) return const SizedBox.shrink();
    final isDuplicate = _scanStatusTone == _ScanStatusTone.duplicate;
    final statusColor = isDuplicate ? AppTheme.warning : AppTheme.success;
    final statusIcon = isDuplicate
        ? Icons.error_outline_rounded
        : Icons.check_rounded;
    final statusTitle = isDuplicate ? 'สแกนซ้ำ' : 'สถานะสแกน';

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Dismissible(
          key: ValueKey('scan-status-$_scanStatusTone-$message'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => _hideScanStatus(),
          child: MouseRegion(
            onEnter: (_) => _holdScanStatus(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _holdScanStatus(),
              child: Material(
                color: statusColor,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'ปิด',
                          onPressed: _hideScanStatus,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = _currentPo.items
        .where((item) => item.status != 'RECEIVED')
        .toList();
    final showPalletSection = _pendingLine != null;

    return PopScope(
      canPop: _pendingLine == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          _resumedPendingLines.insert(0, _pendingLine!);
          _pendingLine = null;
        });
        _reloadPo();
      },
      child: Scaffold(
        appBar: WmsAppBar(title: 'รับสินค้า', userName: widget.fullName),
        body: Stack(
          children: [
            SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: LoadingOverlay(
                      loading: _loading,
                      message: 'กำลังดำเนินการ...',
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReceivingSessionBar(po: _currentPo),
                            const SizedBox(height: 16),
                            if (_lastPalletId != null)
                              CurrentPalletBar(
                                palletId: _lastPalletId!,
                                palletType: _lastPalletType!,
                                onClear: () {
                                  setState(() {
                                    _lastPalletId = null;
                                    _lastPalletType = null;
                                  });
                                },
                              ),
                            if (_lastPalletId != null)
                              const SizedBox(height: 12),
                            if (showPalletSection) ...[
                              PalletScanSection(
                                pendingLine: _pendingLine!,
                                palletController: _palletController,
                                palletFocus: _palletFocus,
                                onScanPallet: _scanPallet,
                                title: 'สแกน Pallet',
                                fieldLabel: 'Pallet ID',
                                fieldHint: 'เช่น PAL-001',
                                buttonLabel: 'ผูก Pallet',
                                conditionMessage:
                                    'สินค้าเป็น ${_pendingLine!.condition} - สแกน Pallet ประเภท ${_pendingLine!.condition}',
                                quantitySuffix: 'ชิ้น',
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!showPalletSection) ...[
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
                                      focusNode: _partFocus,
                                      enabled: _scanningItem == null,
                                      onSubmit: _scanPartId,
                                    ),
                                    if (_scanningItem != null &&
                                        _scanningItem!.serialRequire) ...[
                                      const SizedBox(height: 12),
                                      ScanTextField(
                                        label: 'S/N',
                                        hint: 'สแกน Serial Number',
                                        controller: _serialController,
                                        focusNode: _serialFocus,
                                        onSubmit: _addSerial,
                                      ),
                                      const SizedBox(height: 12),
                                      PrimaryButton(
                                        label: 'เพิ่ม S/N',
                                        icon: MdiIcons.barcodeScan,
                                        onPressed: _addSerial,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildScannedSerialSummary(
                                        _scanningItem!,
                                      ),
                                    ] else if (_scanningItem != null) ...[
                                      const SizedBox(height: 16),
                                      _buildManualQtyEditor(_scanningItem!),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_resumedPendingLines.isNotEmpty) ...[
                              ResumedPendingList(
                                lines: _resumedPendingLines,
                                canAssign: _pendingLine == null,
                                title: 'รอผูก Pallet (จาก session เดิม)',
                                buttonLabel: 'ผูก',
                                quantitySuffix: 'ชิ้น',
                                onAssign: _assignResumedLine,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_assignedLines.isNotEmpty) ...[
                              AssignedList(
                                lines: _assignedLines,
                                titlePrefix: 'ผูก Pallet แล้ว',
                                quantitySuffix: 'ชิ้น',
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (pendingItems.isNotEmpty && !showPalletSection)
                              PendingItemsList(
                                items: pendingItems,
                                title: 'ยังไม่ได้สแกน',
                                quantitySuffix: 'ชิ้น',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildFloatingScanStatus(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scanStatusTimer?.cancel();
    _partController.dispose();
    _partFocus.dispose();
    _qtyController.dispose();
    _manualQtyController.dispose();
    _serialController.dispose();
    _serialFocus.dispose();
    _serialListController.dispose();
    _palletController.dispose();
    _palletFocus.dispose();
    super.dispose();
  }
}
