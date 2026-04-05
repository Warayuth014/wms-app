// lib/screens/flow1/scan_part_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

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

  // ── PO ล่าสุด (อัปเดตได้) ─────────────────
  late POResponse _currentPo;

  // ── Pallet ที่จำไว้ (ใช้ซ้ำ) ──────────────
  String? _lastPalletId;
  String? _lastPalletType;

  // ── Line ที่รอผูก pallet ──────────────────
  ReceiptLineResponse? _pendingLine;

  // ── Lines ที่ผูก pallet แล้ว ──────────────
  final List<_AssignedLine> _assignedLines = [];

  // ── Lines ที่รอผูก pallet จาก resume ──────
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


  // ── สแกน Part ────────────────────────────────
  Future<void> _scanPart() async {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Part ID');
      return;
    }

    // ตรวจว่า Part อยู่ใน PO ไหม
    final inPO = _currentPo.items.any((i) => i.partId == partId);
    if (!inPO) {
      showErrorDialog(
        context,
        message: 'Part $partId ไม่อยู่ใน PO ${_currentPo.poId}',
      );
      return;
    }

    final poItem = _currentPo.items.firstWhere((i) => i.partId == partId);
    _qtyController.text =
        (poItem.qtyRemaining > 0 ? poItem.qtyRemaining : poItem.qtyOrdered)
            .toString();
    _showPartForm(poItem);
  }

  // ── Form กรอก qty (lot/condition แสดงอัตโนมัติจาก master) ────
  void _showPartForm(POItem poItem) {
    final condColor = poItem.condition == 'FG'
        ? AppTheme.success
        : AppTheme.warning;
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
              // Header
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

              // ── Big Condition Badge (FG / PW) ──
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

              // Qty
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'จำนวนที่รับจริง',
                  prefixIcon: Icon(MdiIcons.numeric),
                ),
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
    );
  }

  // ── Confirm Part → API → auto assign or show pallet scan ──
  Future<void> _confirmPart(POItem poItem) async {
    final qty = int.tryParse(_qtyController.text.trim());
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

    setState(() => _loading = true);


    // online → ยิง API
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
      showWarningSnackbar(context, '⚠️ Over receiving: ${line.message}');
    } else {
      showSuccessSnackbar(context, '${line.partId} บันทึกแล้ว');
    }

    _clearFormFields();

    // ── แสดง pallet section ให้เลือกทุกครั้ง (pre-fill pallet เดิมถ้า type ตรง) ──
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
        'Pallet $_lastPalletId เป็น $_lastPalletType ไม่ตรงกับสินค้า ${line.condition} — กรุณาสแกน Pallet ใหม่',
      );
    }
    _palletFocus.requestFocus();
  }

  // ── Assign to Pallet ────────────────────────────
  Future<void> _assignToPallet(
    ReceiptLineResponse line,
    String palletId,
  ) async {
    setState(() => _loading = true);

    final result = await _api.assignPallet(
      sessionId: widget.session.sessionId,
      palletId: palletId,
      palletType: line.condition, // FG or PW
      operatorId: widget.userId,
      lineIds: [line.lineId],
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      // ถ้า auto-assign ล้มเหลว → ให้ scan pallet ใหม่
      setState(() {
        _pendingLine = line;
        _lastPalletId = null;
        _lastPalletType = null;
      });
      showErrorDialog(context, message: result.error ?? 'ผูก Pallet ไม่สำเร็จ');
      _palletFocus.requestFocus();
      return;
    }

    // สำเร็จ → จำ pallet + เพิ่มเข้า assigned list
    final data = result.data!;
    final autoClosed = data['autoClosed'] == true;

    setState(() {
      _lastPalletId = palletId;
      _lastPalletType = line.condition;
      _pendingLine = null;

      // ถ้า partId + palletId เดียวกัน → รวม qty
      final existIdx = _assignedLines.indexWhere(
        (a) => a.partId == line.partId && a.palletId == palletId,
      );
      if (existIdx >= 0) {
        final old = _assignedLines[existIdx];
        _assignedLines[existIdx] = _AssignedLine(
          partId: old.partId,
          itemDesc: old.itemDesc,
          qtyReceived: old.qtyReceived + line.qtyReceived,
          condition: old.condition,
          palletId: old.palletId,
        );
      } else {
        _assignedLines.add(
          _AssignedLine(
            partId: line.partId,
            itemDesc: line.itemDesc,
            qtyReceived: line.qtyReceived,
            condition: line.condition,
            palletId: palletId,
          ),
        );
      }
    });

    showSuccessSnackbar(context, '${line.partId} → Pallet $palletId สำเร็จ');

    // ── Auto-closed → แสดง dialog แล้ว navigate กลับ ──
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

    // โหลด PO ใหม่เพื่ออัพเดท qtyRemaining
    await _reloadPo();

    _partFocus.requestFocus();
  }

  // ── Scan Pallet (manual) ─────────────────────
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

  // ── Assign resumed pending lines ─────────────
  Future<void> _assignResumedLine(ReceiptLineResponse line) async {
    // ถ้ามี pallet ที่ตรง type → auto assign
    if (_lastPalletId != null && _lastPalletType == line.condition) {
      await _assignToPallet(line, _lastPalletId!);
      setState(() => _resumedPendingLines.remove(line));
    } else {
      // ให้ scan pallet ใหม่
      setState(() {
        _pendingLine = line;
        _resumedPendingLines.remove(line);
      });
      _palletFocus.requestFocus();
    }
  }

  void _clearFormFields() {
    _partController.clear();
    _qtyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = _currentPo.items
        .where((i) => i.status != 'RECEIVED')
        .toList();

    final showPalletSection = _pendingLine != null;

    return PopScope(
      canPop: _pendingLine == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // กดกลับขณะรอสแกน Pallet → กลับไปโหมดสแกน Part
        // ทุก line ที่รอ pallet (ไม่ว่าจะ fresh scan หรือ resume) ต้องแสดงใน resumed list
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
                        // ── Session Info ────────────
                        _buildSessionBar(),
                        const SizedBox(height: 16),

                        // ── Pallet ที่ใช้อยู่ ────────
                        if (_lastPalletId != null) _buildCurrentPalletBar(),
                        if (_lastPalletId != null) const SizedBox(height: 12),

                        // ── Scan Pallet Section (เมื่อต้องสแกน pallet ใหม่) ──
                        if (showPalletSection) ...[
                          _buildPalletSection(),
                          const SizedBox(height: 16),
                        ],

                        // ── Scan Part Section (ซ่อนเมื่อรอ pallet) ──
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

                        // ── Resumed pending lines (จาก session เก่า) ──
                        if (_resumedPendingLines.isNotEmpty) ...[
                          _buildResumedPendingList(),
                          const SizedBox(height: 16),
                        ],

                        // ── รายการที่ผูก Pallet แล้ว ──
                        if (_assignedLines.isNotEmpty) ...[
                          _buildAssignedList(),
                          const SizedBox(height: 16),
                        ],

                        // ── Pending PO Items ──────────
                        if (pendingItems.isNotEmpty && !showPalletSection)
                          _buildPendingList(pendingItems),

                        // auto-close เมื่อรับครบ — ไม่ต้องมีปุ่มปิด manual
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

  // ── Session Info Bar ────────────────────────
  Widget _buildSessionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.fileDocumentOutline, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.po.poId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  widget.po.supplierName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Session #${widget.session.sessionId}',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }

  // ── Current Pallet Bar ──────────────────────
  Widget _buildCurrentPalletBar() {
    final color = _lastPalletType == 'FG' ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(MdiIcons.packageVariantClosed, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            'Pallet: $_lastPalletId',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(_lastPalletType!),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _lastPalletId = null;
                _lastPalletType = null;
              });
            },
            child: Icon(
              Icons.close,
              size: 18,
              color: AppTheme.textGrey(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pallet Scan Section ─────────────────────
  Widget _buildPalletSection() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.packageVariantClosed, color: AppTheme.secondary),
              SizedBox(width: 8),
              Text(
                'สแกน Pallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // แสดง item ที่รอผูก
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending, color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pendingLine!.partId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_pendingLine!.qtyReceived} ชิ้น',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(_pendingLine!.condition),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'สินค้าเป็น ${_pendingLine!.condition} — สแกน Pallet ประเภท ${_pendingLine!.condition}',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
          ),
          const SizedBox(height: 12),

          ScanTextField(
            label: 'Pallet ID',
            hint: 'เช่น PAL-001',
            controller: _palletController,
            focusNode: _palletFocus,
            onSubmit: _scanPallet,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'ผูก Pallet',
            icon: MdiIcons.linkVariant,
            onPressed: _scanPallet,
          ),
        ],
      ),
    );
  }

  // ── Resumed Pending Lines ───────────────────
  Widget _buildResumedPendingList() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'รอผูก Pallet (จาก session เดิม)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_resumedPendingLines.length}',
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
          ..._resumedPendingLines.map(
            (line) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
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
                          style: TextStyle(
                            color: AppTheme.textGrey(context),
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
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _pendingLine == null
                        ? () => _assignResumedLine(line)
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('ผูก', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Assigned Lines List ─────────────────────
  Widget _buildAssignedList() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
              const SizedBox(width: 6),
              Text(
                'ผูก Pallet แล้ว (${_assignedLines.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._assignedLines.map(
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
                          style: TextStyle(
                            color: AppTheme.textGrey(context),
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
                      Text(
                        '${line.palletId} (${line.condition})',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
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

  // ── Pending PO Items ────────────────────────
  Widget _buildPendingList(List<POItem> items) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ยังไม่ได้สแกน',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background(context),
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
                          style: TextStyle(
                            color: AppTheme.textGrey(context),
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            if (item.lotNumber != null &&
                                item.lotNumber!.isNotEmpty) ...[
                              Icon(
                                MdiIcons.tagOutline,
                                size: 12,
                                color: AppTheme.textGrey(context),
                              ),
                              const SizedBox(width: 2),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textGrey(context),
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: "Batch No",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: " : ${item.lotNumber!}"),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            StatusBadge(item.condition),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.qtyRemaining > 0 ? item.qtyRemaining : item.qtyOrdered} ชิ้น',
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
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

// ── Assigned Line Model ─────────────────────────
class _AssignedLine {
  final String partId;
  final String itemDesc;
  final int qtyReceived;
  final String condition;
  final String palletId;

  _AssignedLine({
    required this.partId,
    required this.itemDesc,
    required this.qtyReceived,
    required this.condition,
    required this.palletId,
  });
}

// ── Thai Buddhist Era Date Picker ─────────────
class _ThaiDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;

  const _ThaiDatePicker({required this.initialDate, required this.firstDate});

  @override
  State<_ThaiDatePicker> createState() => _ThaiDatePickerState();
}

class _ThaiDatePickerState extends State<_ThaiDatePicker> {
  late int _day;
  late int _month;
  late int _year;

  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;

  static const _monthNames = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
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
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _startYear);
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'ยกเลิก',
                    style: TextStyle(color: AppTheme.textGrey(context)),
                  ),
                ),
                const Text(
                  'เลือกวันหมดอายุ (พ.ศ.)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
          Expanded(
            child: Stack(
              children: [
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
                                            : AppTheme.textPrimary(context))
                                      : Colors.grey.shade300,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
                                    : AppTheme.textPrimary(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                                      : AppTheme.textPrimary(context),
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
