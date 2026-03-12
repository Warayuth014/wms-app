// lib/screens/flow2/unload_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

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
      for (final item in session.items) {
        _partStatus[item.partId] =
            session.confirmedPartIds.contains(item.partId)
            ? 'CONFIRMED'
            : 'PENDING';
      }
    });

    _partFocus.requestFocus();
  }

  // ── Confirm Unload Part ────────────────────
  Future<void> _confirmPart() async {
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

    setState(() => _loading = true);

    final result = await ApiService().confirmUnload(
      sessionId: _sessionId!,
      palletId: _pallet!.palletId,
      partId: partId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    setState(() {
      _partStatus[partId] = 'CONFIRMED';
      _partController.clear();
    });

    showSuccessSnackbar(context, '$partId ($_confirmedCount/$_totalCount)');

    // ครบทุกรายการ → เสนอให้สแกน Pallet ใหม่
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
    setState(() {
      _pallet = null;
      _sessionId = null;
      _sessionOpen = false;
      _partStatus.clear();
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
            const Icon(Icons.forklift, color: AppTheme.textGrey, size: 56),
            const SizedBox(height: 24),
            const Text(
              'โฟล์คลิฟกำลังรับ Pallet...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'กรุณารอสักครู่',
              style: TextStyle(color: AppTheme.textGrey),
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
                const Text(
                  'สแกน Pallet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
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
                              style: const TextStyle(
                                color: AppTheme.textGrey,
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
                const Text(
                  'สแกน Part',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  controller: _partController,
                  label: 'Part ID เช่น PT-1122',
                  hint: 'PT-1122',
                  onSubmit: _confirmPart,
                ),
                const SizedBox(height: 16),
              ],

              // ── Items List ────────────────
              if (_partStatus.isNotEmpty) _buildItemsList(),

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
          const Text(
            'รอ Confirm',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          ...pending.map((i) => _buildItemRow(i, false)),
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
          ...confirmed.map((i) => _buildItemRow(i, true)),
        ],
      ],
    );
  }

  Widget _buildItemRow(dynamic item, bool confirmed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confirmed
            ? AppTheme.success.withValues(alpha: 0.05)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: confirmed
              ? AppTheme.success.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: confirmed ? AppTheme.success : Colors.grey,
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
                    fontSize: 14,
                  ),
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
            '${item.qty} ชิ้น',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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
