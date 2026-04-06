// lib/screens/receiving/scan_part/scan_part_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import 'ui_models/assigned_receiving_line.dart';
import 'widgets/assigned_list.dart';
import 'widgets/current_pallet_bar.dart';
import 'widgets/pallet_scan_section.dart';
import 'widgets/pending_items_list.dart';
import 'widgets/receiving_session_bar.dart';
import 'widgets/resumed_pending_list.dart';

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
  final _partFocus = FocusNode();
  final _qtyController = TextEditingController();
  final _palletController = TextEditingController();
  final _palletFocus = FocusNode();
  final _api = ApiService();

  bool _loading = false;
  late POResponse _currentPo;

  String? _lastPalletId;
  String? _lastPalletType;
  ReceiptLineResponse? _pendingLine;

  final List<AssignedReceivingLine> _assignedLines = [];
  final List<ReceiptLineResponse> _resumedPendingLines = [];

  @override
  void initState() {
    super.initState();
    _currentPo = widget.po;
    if (widget.session.pendingLines.isNotEmpty) {
      _resumedPendingLines.addAll(widget.session.pendingLines);
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

  Future<void> _scanPart() async {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Part ID');
      return;
    }

    final inPo = _currentPo.items.any((item) => item.partId == partId);
    if (!inPo) {
      showErrorDialog(
        context,
        message: 'Part $partId ไม่อยู่ใน PO ${_currentPo.poId}',
      );
      return;
    }

    final poItem = _currentPo.items.firstWhere((item) => item.partId == partId);
    _qtyController.text =
        (poItem.qtyRemaining > 0 ? poItem.qtyRemaining : poItem.qtyOrdered)
            .toString();
    _showPartForm(poItem);
  }

  void _showPartForm(POItem poItem) {
    final condColor =
        poItem.condition == 'FG' ? AppTheme.success : AppTheme.warning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom,
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
              if (poItem.expiredDate != null && poItem.expiredDate!.isNotEmpty)
                InfoRow(label: 'Exp', value: poItem.expiredDate!),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'จำนวนที่รับจริง',
                  prefixIcon: Icon(MdiIcons.numeric),
                ),
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
    );
  }

  Future<void> _confirmPart(POItem poItem) async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      showErrorDialog(context, message: 'จำนวนไม่ถูกต้อง');
      return;
    }

    final maxQty =
        poItem.qtyRemaining > 0 ? poItem.qtyRemaining : poItem.qtyOrdered;
    if (qty > maxQty) {
      showErrorDialog(
        context,
        message: 'รับได้สูงสุด $maxQty ชิ้น (รับไปแล้ว ${poItem.qtyReceived} ชิ้น)',
      );
      return;
    }

    setState(() => _loading = true);

    final result = await _api.scanReceiptPart(
      sessionId: widget.session.sessionId,
      poId: widget.po.poId,
      partId: poItem.partId,
      qtyReceived: qty,
      operatorId: widget.userId,
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
    } else {
      showSuccessSnackbar(context, '${line.partId} บันทึกแล้ว');
    }

    _clearFormFields();

    setState(() {
      _pendingLine = line;
      if (_lastPalletId != null && _lastPalletType == line.condition) {
        _palletController.text = _lastPalletId!;
      } else {
        _palletController.clear();
      }
    });

    if (_lastPalletId != null && _lastPalletType != line.condition) {
      showWarningSnackbar(
        context,
        'Pallet $_lastPalletId เป็น $_lastPalletType ไม่ตรงกับสินค้า ${line.condition} - กรุณาสแกน Pallet ใหม่',
      );
    }

    _palletFocus.requestFocus();
  }

  Future<void> _assignToPallet(ReceiptLineResponse line, String palletId) async {
    setState(() => _loading = true);

    final result = await _api.assignPallet(
      sessionId: widget.session.sessionId,
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
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                poStatus == 'RECEIVED'
                    ? Icons.check_circle
                    : Icons.warning_amber,
                color: poStatus == 'RECEIVED'
                    ? AppTheme.success
                    : AppTheme.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poStatus == 'RECEIVED'
                      ? 'รับสินค้าครบแล้ว'
                      : 'รับสินค้าบางส่วน',
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
                style: TextStyle(
                  color: AppTheme.textGrey(context),
                  fontSize: 13,
                ),
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

  void _clearFormFields() {
    _partController.clear();
    _qtyController.clear();
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
        body: SafeArea(
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
                        ReceivingSessionBar(
                          po: _currentPo,
                          session: widget.session,
                        ),
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
                        if (_lastPalletId != null) const SizedBox(height: 12),
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
                                  onSubmit: _scanPart,
                                ),
                                const SizedBox(height: 12),
                                PrimaryButton(
                                  label: 'สแกน',
                                  icon: MdiIcons.barcodeScan,
                                  onPressed: _scanPart,
                                ),
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
      ),
    );
  }

  @override
  void dispose() {
    _partController.dispose();
    _partFocus.dispose();
    _qtyController.dispose();
    _palletController.dispose();
    _palletFocus.dispose();
    super.dispose();
  }
}
