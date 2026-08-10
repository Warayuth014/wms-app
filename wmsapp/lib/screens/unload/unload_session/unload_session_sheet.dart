// lib/screens/unload/unload_session/unload_session_sheet.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../putaway/shared/putaway_shared_widgets.dart';
import 'widgets/lists/unload_items_list.dart';
import 'widgets/pallet/unload_pallet_info_card.dart';
import 'widgets/scan/unload_pallet_scan_section.dart';
import 'widgets/scan/unload_part_scan_section.dart';
import 'widgets/status/unload_progress_bar.dart';
import 'widgets/status/unload_return_animation.dart';

class UnloadSessionSheet extends StatefulWidget {
  final StationInfo station;
  final String userId;
  final String fullName;

  const UnloadSessionSheet({
    super.key,
    required this.station,
    required this.userId,
    required this.fullName,
  });

  @override
  State<UnloadSessionSheet> createState() => _UnloadSessionSheetState();
}

class _UnloadSessionSheetState extends State<UnloadSessionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowController;
  late final Animation<double> _arrowAnimation;

  final _palletController = TextEditingController();
  final _palletFocus = FocusNode();
  final _partController = TextEditingController();
  final _partFocus = FocusNode();
  final _serialController = TextEditingController();
  final _serialFocus = FocusNode();

  UnloadSession? _session;
  int? _sessionId;
  bool _loading = false;
  bool _sessionOpen = false;
  bool _returning = false;
  int? _scannedLineId;
  final List<String> _scannedSerials = [];

  // key = UnloadItem.lineId (ไม่ใช่ partId — 1 Part อาจมีหลาย Lot บน pallet เดียวกัน)
  final Map<int, String> _partStatus = {};
  final Map<int, TextEditingController> _qtyCtrl = {};

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

  @override
  void dispose() {
    _arrowController.dispose();
    _palletController.dispose();
    _palletFocus.dispose();
    _partController.dispose();
    _partFocus.dispose();
    _serialController.dispose();
    _serialFocus.dispose();
    _disposeQtyControllers();
    super.dispose();
  }

  int get _confirmedCount =>
      _partStatus.values.where((status) => status == 'CONFIRMED').length;

  int get _totalCount => _partStatus.length;

  bool get _allConfirmed => _totalCount > 0 && _confirmedCount == _totalCount;

  void _buildQtyControllers() {
    _disposeQtyControllers();
    if (_session == null) return;

    for (final item in _session!.items) {
      _qtyCtrl[item.lineId] = TextEditingController(text: '${item.qty}');
    }
  }

  void _disposeQtyControllers() {
    for (final controller in _qtyCtrl.values) {
      controller.dispose();
    }
    _qtyCtrl.clear();
  }

  Future<void> _scanPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await ApiService().openUnloadSession(
      palletId: palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Pallet นี้');
      _palletController.clear();
      _palletFocus.requestFocus();
      return;
    }

    final session = result.data!;
    setState(() {
      _session = session;
      _sessionId = session.sessionId;
      _sessionOpen = true;
      _scannedLineId = null;
      _partStatus.clear();

      for (final item in session.items) {
        _partStatus[item.lineId] =
            session.confirmedLineIds.contains(item.lineId)
            ? 'CONFIRMED'
            : 'PENDING';
      }
    });

    _buildQtyControllers();
    _partFocus.requestFocus();
  }

  // โหลด session ปัจจุบันซ้ำจาก server — ใช้หลัง confirm สำเร็จ เพื่อให้ LineId/qty ตรงกับจริงเสมอ
  // (ถ้ามีเศษเหลือ backend จะสร้าง UnloadLine ใหม่ที่มี LineId ต่างจากเดิม แก้ปัญหาโดยโหลดใหม่แทนการ patch เอง)
  Future<void> _reloadSession() async {
    final session = _session;
    if (session == null) return;

    final result = await ApiService().openUnloadSession(
      palletId: session.palletId,
      operatorId: widget.userId,
    );
    if (!mounted || !result.success) return;

    final fresh = result.data!;
    setState(() {
      _session = fresh;
      _sessionId = fresh.sessionId;
      _partStatus.clear();
      for (final item in fresh.items) {
        _partStatus[item.lineId] = fresh.confirmedLineIds.contains(item.lineId)
            ? 'CONFIRMED'
            : 'PENDING';
      }
    });
    _buildQtyControllers();
  }

  // สแกน Part ID — แสดงทุก Lot ของ Part นั้นในลิสต์เสมออยู่แล้ว (ไม่ popup เลือก lot)
  // ถ้ามีหลาย Lot ที่ยัง PENDING เลือก lot แรกที่เจอไปก่อน ผู้ใช้แตะการ์ด lot อื่นในลิสต์เพื่อสลับได้เอง
  void _scanPart() {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    final matches =
        _session?.items.where((i) => i.partId == partId).toList() ?? [];

    if (matches.isEmpty) {
      showErrorDialog(context, message: 'Part $partId ไม่อยู่ใน Pallet นี้');
      _partController.clear();
      return;
    }

    final pending = matches
        .where((i) => _partStatus[i.lineId] != 'CONFIRMED')
        .toList();

    if (pending.isEmpty) {
      showWarningSnackbar(context, 'Part $partId ยืนยันไปแล้วทุก Lot');
      _partController.clear();
      return;
    }

    setState(() {
      _scannedLineId = pending.first.lineId;
      _scannedSerials.clear();
      _partController.clear();
    });
  }

  void _selectLine(int lineId) {
    if (_partStatus[lineId] == 'CONFIRMED') return;
    if (_scannedLineId == lineId) return;
    setState(() {
      _scannedLineId = lineId;
      _scannedSerials.clear();
    });
  }

  // สแกน S/N ทีละตัว inline ในการ์ด (ไม่ใช้ popup) — เฉพาะ Part ที่มี S/N เท่านั้น
  void _addSerial() {
    final item = _currentScannedItem();
    if (item == null) return;

    final sn = _serialController.text.trim().toUpperCase();
    _serialController.clear();
    if (sn.isEmpty) return;

    if (!item.serialNumbers.contains(sn)) {
      showErrorDialog(
        context,
        message: 'S/N "$sn" ไม่ใช่ของรายการนี้ หรือถูกใช้ไปแล้ว',
      );
      _serialFocus.requestFocus();
      return;
    }
    if (_scannedSerials.contains(sn)) {
      showErrorDialog(context, message: 'สแกน S/N "$sn" ซ้ำ');
      _serialFocus.requestFocus();
      return;
    }
    if (_scannedSerials.length >= item.qty) {
      showErrorDialog(context, message: 'สแกนครบจำนวนแล้ว (${item.qty})');
      return;
    }

    setState(() => _scannedSerials.add(sn));
    _serialFocus.requestFocus();
  }

  void _removeSerial(String sn) {
    setState(() => _scannedSerials.remove(sn));
  }

  UnloadItem? _currentScannedItem() {
    final lineId = _scannedLineId;
    if (lineId == null || _session == null) return null;
    return _session!.items.firstWhere((i) => i.lineId == lineId);
  }

  bool _canConfirmScanned() {
    final item = _currentScannedItem();
    if (item == null) return false;
    if (item.serialRequire) return _scannedSerials.length == item.qty;
    return true;
  }

  Future<void> _confirmScannedPart() async {
    final session = _session;
    final sessionId = _sessionId;
    final item = _currentScannedItem();
    if (session == null || sessionId == null || item == null) return;

    int qty;
    List<String>? serialNumbers;

    if (item.serialRequire) {
      if (_scannedSerials.length != item.qty) {
        showErrorDialog(
          context,
          message:
              'กรุณาสแกน S/N ให้ครบ (${_scannedSerials.length}/${item.qty})',
        );
        return;
      }
      qty = _scannedSerials.length;
      serialNumbers = List<String>.of(_scannedSerials);
    } else {
      final qtyText = _qtyCtrl[item.lineId]?.text.trim() ?? '';
      qty = int.tryParse(qtyText) ?? 0;

      if (qty <= 0) {
        showErrorDialog(context, message: 'กรุณาระบุจำนวนที่ต้องการ Unload');
        return;
      }
      if (qty > item.qty) {
        showErrorDialog(
          context,
          message: 'จำนวนเกินที่มีบน Pallet (${item.qty})',
        );
        return;
      }
    }

    setState(() => _loading = true);
    final result = await ApiService().confirmUnload(
      sessionId: sessionId,
      palletId: session.palletId,
      partId: item.partId,
      lineId: item.lineId,
      operatorId: widget.userId,
      qtyUnloaded: qty,
      serialNumbers: serialNumbers,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => _loading = false);
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    final remainder = item.qty - qty;
    setState(() {
      _scannedLineId = null;
      _scannedSerials.clear();
    });
    await _reloadSession();

    if (!mounted) return;
    setState(() => _loading = false);

    showSuccessSnackbar(
      context,
      remainder > 0
          ? '${item.partId} หยิบ $qty ชิ้น (เหลือ $remainder)'
          : '${item.partId} ครบ $qty ชิ้น ($_confirmedCount/$_totalCount)',
    );

    _partFocus.requestFocus();

    if (_allConfirmed) {
      await _showNextPalletDialog();
    }
  }

  Future<void> _returnPallet() async {
    final session = _session;
    if (session == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'คืน Pallet',
      message:
          'คืน Pallet ${session.palletId}\n'
          'ให้โฟล์คลิฟท์อัตโนมัติรับกลับ ASRS?\n\n'
          '(หยิบออกแล้ว $_confirmedCount/$_totalCount รายการ)',
      confirmLabel: 'คืน Pallet',
    );

    if (!confirm || !mounted) return;

    setState(() => _returning = true);
    final results = await Future.wait([
      ApiService().returnPalletToAsis(
        palletId: session.palletId,
        sessionId: _sessionId,
      ),
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (!mounted) return;
    setState(() => _returning = false);

    final result = results.first as ApiResult<Map<String, dynamic>>;
    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    _resetForNextPallet();
  }

  Future<void> _showNextPalletDialog() async {
    await _returnPallet();
  }

  void _resetForNextPallet() {
    _disposeQtyControllers();
    setState(() {
      _session = null;
      _sessionId = null;
      _sessionOpen = false;
      _scannedLineId = null;
      _partStatus.clear();
      _palletController.clear();
      _partController.clear();
    });
    _palletFocus.requestFocus();
  }

  bool get _canDismiss => !_loading && !_returning;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final maxHeight = mq.size.height * 0.92;

    return PopScope(
      canPop: _canDismiss,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: LoadingOverlay(
          loading: _loading,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              _buildHeader(),
              const SizedBox(height: 12),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
                  child: _returning
                      ? UnloadReturnAnimation(arrowAnimation: _arrowAnimation)
                      : _buildSessionBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.station.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(widget.station.icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.station.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.station.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            if (_sessionOpen)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'สแกน Pallet ใหม่',
                onPressed: _resetForNextPallet,
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'ปิด',
              onPressed: _canDismiss ? () => Navigator.pop(context) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_sessionOpen) ...[_buildProgressBar(), const SizedBox(height: 16)],
        if (!_sessionOpen) _buildPalletScanSection(),
        if (_session != null) _buildPalletInfoSection(),
        if (_sessionOpen) _buildPartScanSection(),
        if (_partStatus.isNotEmpty) _buildItemsList(),
        if (_scannedLineId != null) ...[
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'ยืนยัน Unload: ${_scannedItemLabel()}',
            icon: Icons.check,
            onPressed: _canConfirmScanned() ? _confirmScannedPart : null,
          ),
          const SizedBox(height: 8),
          DangerButton(
            label: 'ยกเลิก',
            icon: Icons.close,
            onPressed: () {
              setState(() {
                _scannedLineId = null;
                _scannedSerials.clear();
              });
              _partFocus.requestFocus();
            },
          ),
        ],
        if (_sessionOpen) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _returnPallet,
            icon: Icon(MdiIcons.undoVariant, color: AppTheme.danger),
            label: const Text(
              'คืน Pallet',
              style: TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
              ),
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
    );
  }

  Widget _buildPalletScanSection() => UnloadPalletScanSection(
    controller: _palletController,
    onSubmit: () {
      _scanPallet();
    },
  );

  Widget _buildPalletInfoSection() => Column(
    children: [
      UnloadPalletInfoCard(
        palletId: _session!.palletId,
        itemCount: _session!.items.length,
        sessionId: _sessionId,
        confirmedCount: _confirmedCount,
        totalCount: _totalCount,
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _buildPartScanSection() =>
      UnloadPartScanSection(controller: _partController, onSubmit: _scanPart);

  Widget _buildProgressBar() => UnloadProgressBar(
    confirmedCount: _confirmedCount,
    totalCount: _totalCount,
    allConfirmed: _allConfirmed,
  );

  Widget _buildItemsList() => UnloadItemsList(
    items: _session!.items,
    partStatus: _partStatus,
    qtyControllers: _qtyCtrl,
    scannedLineId: _scannedLineId,
    onSelectLine: _selectLine,
    scannedSerials: _scannedSerials,
    serialController: _serialController,
    serialFocus: _serialFocus,
    onAddSerial: _addSerial,
    onRemoveSerial: _removeSerial,
  );

  String _scannedItemLabel() {
    final lineId = _scannedLineId;
    if (lineId == null || _session == null) return '';
    final item = _session!.items.firstWhere((i) => i.lineId == lineId);
    return item.lotNumber != null && item.lotNumber!.isNotEmpty
        ? '${item.partId} (${item.lotNumber})'
        : item.partId;
  }
}
