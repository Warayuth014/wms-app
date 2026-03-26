// lib/screens/flow2/unload_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import '../../widgets/part_thumbnail.dart';

class UnloadScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const UnloadScreen({super.key, required this.userId, required this.fullName});

  @override
  State<UnloadScreen> createState() => _UnloadScreenState();
}

class _UnloadScreenState extends State<UnloadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;
  final _palletController = TextEditingController();
  final _palletFocus = FocusNode();
  final _partController = TextEditingController();
  final _partFocus = FocusNode();

  PalletScanResponse? _pallet;
  int? _sessionId;
  bool _loading = false;
  bool _sessionOpen = false;
  bool _returning = false;

  // partId → PENDING | CONFIRMED
  final Map<String, String> _partStatus = {};

  // qty controllers & scanned part highlight
  final Map<String, TextEditingController> _qtyCtrl = {};
  String? _scannedPartId; // part ที่ scan แล้วรอกด confirm

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  int get _confirmedCount =>
      _partStatus.values.where((s) => s == 'CONFIRMED').length;
  int get _totalCount => _partStatus.length;
  bool get _allConfirmed => _totalCount > 0 && _confirmedCount == _totalCount;

  void _buildQtyControllers() {
    _disposeQtyCtrl();
    if (_pallet == null) return;
    for (final item in _pallet!.items) {
      _qtyCtrl[item.partId] = TextEditingController(text: '${item.qty}');
    }
  }

  void _disposeQtyCtrl() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    _qtyCtrl.clear();
  }

  // ── สแกน Pallet ───────────────────────────
  Future<void> _scanPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);

    final result = await ApiService().scanPalletForUnload(palletId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Pallet นี้');
      _palletController.clear();
      _palletFocus.requestFocus();
      return;
    }

    setState(() => _pallet = result.data);

    // PW → ต้องติดสติ๊กเกอร์ก่อน
    if (_pallet!.needsLabeling) {
      _showLabelingDialog();
      return;
    }

    await _openSession();
  }

  // ── PW Labeling Dialog ─────────────────────
  Future<void> _showLabelingDialog() async {
    final confirm = await showConfirmDialog(
      context,
      title: '⚠️ ต้องติดสติ๊กเกอร์',
      message:
          'Pallet ${_pallet!.palletId} เป็นประเภท PW\n'
          'กรุณาส่งไปจุด Labeling ก่อน\n'
          'แล้วกดยืนยันเมื่อติดเรียบร้อย',
      confirmLabel: 'ติดแล้ว ยืนยัน',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await ApiService().confirmLabeling(
      palletId: _pallet!.palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    showSuccessSnackbar(context, 'เปลี่ยนเป็น FG แล้ว');
    await _openSession();
  }

  // ── เปิด Unload Session ────────────────────
  Future<void> _openSession() async {
    if (_pallet == null) return;
    setState(() => _loading = true);

    final result = await ApiService().openUnloadSession(
      palletId: _pallet!.palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เปิด session ไม่ได้');
      return;
    }

    final session = result.data!;
    setState(() {
      _sessionId = session.sessionId;
      _sessionOpen = true;
      _partStatus.clear();
      _scannedPartId = null;

      // อัพเดท items จาก session (มี remaining qty ที่ถูกต้อง)
      _pallet = PalletScanResponse(
        palletId: _pallet!.palletId,
        type: _pallet!.type,
        status: _pallet!.status,
        needsLabeling: false,
        items: session.items,
        message: '',
      );

      for (final item in session.items) {
        _partStatus[item.partId] =
            session.confirmedPartIds.contains(item.partId)
            ? 'CONFIRMED'
            : 'PENDING';
      }
    });

    _buildQtyControllers();
    _partFocus.requestFocus();
  }

  // ── Scan Part → ไฮไลท์ รอกด Confirm ────────
  void _scanPart() {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    if (!_partStatus.containsKey(partId)) {
      showErrorDialog(context, message: 'Part $partId ไม่อยู่ใน Pallet นี้');
      _partController.clear();
      return;
    }

    if (_partStatus[partId] == 'CONFIRMED') {
      showWarningSnackbar(context, 'Part $partId confirm ไปแล้ว');
      _partController.clear();
      return;
    }

    setState(() {
      _scannedPartId = partId;
      _partController.clear();
    });
  }

  // ── Confirm Unload Part (กดปุ่ม) ───────────
  Future<void> _confirmScannedPart() async {
    if (_scannedPartId == null) return;
    final partId = _scannedPartId!;

    // อ่าน qty จาก controller
    final qtyText = _qtyCtrl[partId]?.text.trim() ?? '';
    final qty = int.tryParse(qtyText) ?? 0;

    if (qty <= 0) {
      showErrorDialog(context, message: 'กรุณาระบุจำนวนที่ต้องการ Unload');
      return;
    }

    // หา item เดิมเพื่อเช็ค max qty
    final item = _pallet!.items.firstWhere((i) => i.partId == partId);
    if (qty > item.qty) {
      showErrorDialog(
        context,
        message: 'จำนวนเกินที่มีบน Pallet (${item.qty})',
      );
      return;
    }

    setState(() => _loading = true);

    final result = await ApiService().confirmUnload(
      sessionId: _sessionId!,
      palletId: _pallet!.palletId,
      partId: partId,
      operatorId: widget.userId,
      qtyUnloaded: qty,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    // คำนวณส่วนที่เหลือบน Pallet
    final remainder = item.qty - qty;

    setState(() {
      _scannedPartId = null;

      if (remainder > 0) {
        // ยัง unload ไม่หมด → อัพเดท qty ที่เหลือ ให้สแกนซ้ำได้
        final idx = _pallet!.items.indexWhere((i) => i.partId == partId);
        if (idx >= 0) {
          final oldItem = _pallet!.items[idx];
          final updatedItems = List<UnloadItem>.from(_pallet!.items);
          updatedItems[idx] = UnloadItem(
            partId: oldItem.partId,
            owner: oldItem.owner,
            brand: oldItem.brand,
            itemDesc: oldItem.itemDesc,
            lotNumber: oldItem.lotNumber,
            expiredDate: oldItem.expiredDate,
            qty: remainder,
            condition: oldItem.condition,
          );
          _pallet = PalletScanResponse(
            palletId: _pallet!.palletId,
            type: _pallet!.type,
            status: _pallet!.status,
            needsLabeling: _pallet!.needsLabeling,
            items: updatedItems,
            message: _pallet!.message,
          );
          // อัพเดท qty controller
          _qtyCtrl[partId]?.text = '$remainder';
        }
        // ยังคง PENDING → สแกนซ้ำได้
        _partStatus[partId] = 'PENDING';
      } else {
        // unload หมดแล้ว → CONFIRMED
        _partStatus[partId] = 'CONFIRMED';
      }
    });

    showSuccessSnackbar(
      context,
      remainder > 0
          ? '$partId — หยิบ $qty ชิ้น (เหลือ $remainder)'
          : '$partId — $qty ชิ้น ($_confirmedCount/$_totalCount)',
    );

    _partFocus.requestFocus();

    // ครบทุกรายการ → เสนอให้คืน Pallet
    if (_allConfirmed) _showNextPalletDialog();
  }

  // ── คืน Pallet ให้ AGV รับกลับ ASRS ──────
  Future<void> _returnPallet() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'คืน Pallet',
      message:
          'คืน Pallet ${_pallet!.palletId}\n'
          'ให้โฟล์คลิฟอัตโนมัติรับกลับ ASRS?\n\n'
          '(หยิบออกแล้ว $_confirmedCount/$_totalCount รายการ)',
      confirmLabel: 'คืน Pallet',
    );
    if (!confirm || !mounted) return;

    setState(() => _returning = true);

    final results = await Future.wait([
      ApiService().returnPalletToAsis(
        palletId: _pallet!.palletId,
        sessionId: _sessionId,
        operatorId: widget.userId,
      ),
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (!mounted) return;
    setState(() => _returning = false);

    final result = results[0] as ApiResult<Map<String, dynamic>>;
    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    _resetForNextPallet();
  }

  // ── ครบทุกรายการ → คืน pallet อัตโนมัติ ──
  Future<void> _showNextPalletDialog() async {
    await _returnPallet();
  }

  void _resetForNextPallet() {
    _disposeQtyCtrl();
    setState(() {
      _pallet = null;
      _sessionId = null;
      _sessionOpen = false;
      _partStatus.clear();
      _scannedPartId = null;
      _palletController.clear();
      _partController.clear();
    });
    _palletFocus.requestFocus();
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _palletController.dispose();
    _palletFocus.dispose();
    _partController.dispose();
    _partFocus.dispose();
    _disposeQtyCtrl();
    super.dispose();
  }

  Widget _buildReturnAnimation() {
    return Scaffold(
      appBar: WmsAppBar(title: 'Unload', userName: widget.fullName),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _arrowAnimation,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _arrowAnimation.value),
                child: const Icon(
                  Icons.arrow_upward,
                  color: AppTheme.warning,
                  size: 80,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Icon(Icons.forklift, color: AppTheme.textGrey(context), size: 56),
            const SizedBox(height: 24),
            Text(
              'โฟล์คลิฟกำลังรับ Pallet...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณารอสักครู่',
              style: TextStyle(color: AppTheme.textGrey(context)),
            ),
            const SizedBox(height: 32),
            const _CountdownTimer(seconds: 5),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_returning) return _buildReturnAnimation();

    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        appBar: WmsAppBar(
          title: 'Unload',
          userName: widget.fullName,
          actions: [
            if (_sessionOpen)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'สแกน Pallet ใหม่',
                onPressed: _resetForNextPallet,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress (ถ้ามี session) ──
              if (_sessionOpen) ...[
                _buildProgressBar(),
                const SizedBox(height: 16),
              ],

              // ── Scan Pallet ───────────────
              if (!_sessionOpen) ...[
                Text(
                  'สแกน Pallet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  controller: _palletController,
                  label: 'Pallet ID เช่น PAL-001',
                  hint: 'PAL-001',
                  onSubmit: _scanPallet,
                ),
              ],

              // ── Pallet Info ───────────────
              if (_pallet != null) ...[
                WmsCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pallet!.palletId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Session #$_sessionId · ${_pallet!.items.length} รายการ',
                              style: TextStyle(
                                color: AppTheme.textGrey(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_confirmedCount/$_totalCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Scan Part ─────────────────
              if (_sessionOpen) ...[
              Text(
                  'สแกน Part',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  controller: _partController,
                  label: 'Part ID เช่น PT-1122',
                  hint: 'PT-1122',
                  onSubmit: _scanPart,
                ),
                const SizedBox(height: 16),
              ],

              // ── Items List (with qty editors) ──
              if (_partStatus.isNotEmpty) _buildItemsList(),

              // ── Confirm Unload button (เมื่อ scan part แล้ว) ──
              if (_scannedPartId != null) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'ยืนยัน Unload: $_scannedPartId',
                  icon: Icons.check,
                  onPressed: _confirmScannedPart,
                ),
                const SizedBox(height: 8),
                DangerButton(
                  label: 'ยกเลิก',
                  icon: Icons.close,
                  onPressed: () {
                    setState(() => _scannedPartId = null);
                    _partFocus.requestFocus();
                  },
                ),
              ],

              // ── Return Pallet button ──────
              if (_sessionOpen) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _returnPallet,
                  icon: const Icon(Icons.reply, color: AppTheme.danger),
                  label: const Text(
                    'คืน Pallet',
                    style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.danger, width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _totalCount == 0 ? 0.0 : _confirmedCount / _totalCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Unload แล้ว $_confirmedCount จาก $_totalCount',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _allConfirmed ? AppTheme.success : AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    final items = _pallet!.items;
    final pending = items
        .where((i) => _partStatus[i.partId] == 'PENDING')
        .toList();
    final confirmed = items
        .where((i) => _partStatus[i.partId] == 'CONFIRMED')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pending.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.inventory_2, color: AppTheme.textPrimary(context), size: 18),
              const SizedBox(width: 6),
              Text(
                'รอ Unload (ระบุจำนวนที่จะหยิบออก)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pending.map((i) => _buildItemCard(i, false)),
          const SizedBox(height: 16),
        ],
        if (confirmed.isNotEmpty) ...[
          const Text(
            'Confirmed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 8),
          ...confirmed.map((i) => _buildItemCard(i, true)),
        ],
      ],
    );
  }

  Widget _buildItemCard(UnloadItem item, bool confirmed) {
    final isScanned = _scannedPartId == item.partId;
    final ctrl = _qtyCtrl[item.partId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confirmed
            ? AppTheme.success.withValues(alpha: 0.05)
            : isScanned
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confirmed
              ? AppTheme.success.withValues(alpha: 0.3)
              : isScanned
                  ? AppTheme.primary
                  : AppTheme.border(context),
          width: isScanned ? 2 : 1,
        ),
        boxShadow: [
          if (!confirmed)
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
          Row(
            children: [
              PartThumbnail(imageUrl: item.imageUrl, size: 36),
              const SizedBox(width: 10),
              Icon(
                confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: confirmed
                    ? AppTheme.success
                    : isScanned
                        ? AppTheme.primary
                        : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
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
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        if (item.lotNumber != null && item.lotNumber!.isNotEmpty) ...[
                          Icon(Icons.label_outline, size: 12, color: AppTheme.textGrey(context)),
                          const SizedBox(width: 2),
                          Text(
                            'Batch No.: ${item.lotNumber}',
                            style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${item.owner} / ${item.brand}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isScanned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SCANNED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (!confirmed) ...[
            const Divider(height: 14),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'บน Pallet: ${item.qty} ชิ้น',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                    Text(
                      '${item.owner} / ${item.brand}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'จำนวน Unload: ',
                  style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
                ),
                SizedBox(
                  width: 72,
                  height: 38,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: isScanned,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 14),
            Row(
              children: [
                Text(
                  '${item.owner} / ${item.brand}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_qtyCtrl[item.partId]?.text ?? item.qty} ชิ้น',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final int seconds;
  const _CountdownTimer({required this.seconds});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_remaining วินาที',
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppTheme.warning,
      ),
    );
  }
}
