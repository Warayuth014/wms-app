// lib/screens/flow2/unload_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/offline_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/wms_models.dart';
import 'load_basket_screen.dart';

class UnloadScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final UnloadSession session;
  final PalletScanResponse pallet;

  const UnloadScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.session,
    required this.pallet,
  });

  @override
  State<UnloadScreen> createState() => _UnloadScreenState();
}

class _UnloadScreenState extends State<UnloadScreen> {
  final _partController = TextEditingController();
  final _api = ApiService();

  // track status แต่ละ Part
  // key = partId, value = PENDING | CONFIRMED
  late Map<String, String> _partStatus;

  bool _loading = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    // init ทุก Part เป็น PENDING
    _partStatus = {
      for (final item in widget.session.items) item.partId: 'PENDING',
    };
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService().checkNow();
    setState(() => _isOnline = online);
  }

  int get _confirmedCount =>
      _partStatus.values.where((s) => s == 'CONFIRMED').length;

  int get _totalCount => _partStatus.length;

  bool get _allConfirmed => _confirmedCount == _totalCount;

  // ── Confirm Unload ────────────────────────────
  Future<void> _confirmUnload() async {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Part ID');
      return;
    }

    // ตรวจว่า Part อยู่ใน session ไหม
    if (!_partStatus.containsKey(partId)) {
      showErrorDialog(context, message: 'Part $partId ไม่อยู่ใน session นี้');
      return;
    }

    // ตรวจว่า confirm ไปแล้วหรือยัง
    if (_partStatus[partId] == 'CONFIRMED') {
      showWarningSnackbar(context, 'Part $partId confirm ไปแล้ว');
      _partController.clear();
      return;
    }

    // ยืนยัน
    final item = widget.session.items.firstWhere((i) => i.partId == partId);

    final confirm = await showConfirmDialog(
      context,
      title: 'Confirm นำสินค้าออก',
      message:
          'นำ ${item.partId} ออกจาก Pallet แล้ว?\n'
          '${item.itemDesc}\n'
          'จำนวน: ${item.qty} ชิ้น',
      confirmLabel: 'Confirm',
    );
    if (!confirm) return;

    setState(() => _loading = true);

    // offline → queue
    if (!_isOnline) {
      await OfflineService().addToQueue(
        action: 'confirm-unload',
        data: {
          'sessionId': widget.session.sessionId,
          'palletId': widget.pallet.palletId,
          'partId': partId,
          'operatorId': widget.userId,
        },
      );

      setState(() {
        _loading = false;
        _partStatus[partId] = 'CONFIRMED';
        _partController.clear();
      });

      if (!mounted) return;

      showWarningSnackbar(context, 'บันทึกแบบ offline');

      if (_allConfirmed) _goToStep2();
      return;
    }

    // online → API
    final result = await _api.confirmUnload(
      sessionId: widget.session.sessionId,
      palletId: widget.pallet.palletId,
      partId: partId,
      operatorId: widget.userId,
    );

    setState(() => _loading = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() {
      _partStatus[partId] = 'CONFIRMED';
      _partController.clear();
    });

    final allConfirmed = result.data!['allConfirmed'] as bool;

    showSuccessSnackbar(
      context,
      '✅ $partId confirmed ($_confirmedCount/$_totalCount)',
    );

    if (allConfirmed) {
      await Future.delayed(const Duration(milliseconds: 500));
      _goToStep2();
    }
  }

  // ── ไป Step 2 ────────────────────────────────
  void _goToStep2() {
    showSuccessSnackbar(context, '✅ ครบทุกรายการ ไป Step 2 ได้เลย');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoadBasketScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          session: widget.session,
          pallet: widget.pallet,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Step 1 — Unload', userName: widget.fullName),
      body: Column(
        children: [
          if (!_isOnline) const OfflineBanner(pendingCount: 0),

          // ── Progress Bar ────────────────────
          _buildProgressBar(),

          Expanded(
            child: LoadingOverlay(
              loading: _loading,
              message: 'กำลัง confirm...',
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
                            Icons.inventory_2,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.pallet.palletId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Session #${widget.session.sessionId}',
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$_confirmedCount / $_totalCount',
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

                    // ── Scan Part ───────────────
                    WmsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'สแกน Part เพื่อ Confirm',
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
                            onSubmit: _confirmUnload,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Confirm นำออก',
                            icon: Icons.check_circle,
                            onPressed: _confirmUnload,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Items List ──────────────
                    _buildItemsList(),
                    const SizedBox(height: 16),

                    // ── Manual Go Step 2 ────────
                    if (_allConfirmed)
                      PrimaryButton(
                        label: 'ไป Step 2 →',
                        icon: Icons.arrow_forward,
                        onPressed: _goToStep2,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress Bar ─────────────────────────────
  Widget _buildProgressBar() {
    final progress = _totalCount == 0 ? 0.0 : _confirmedCount / _totalCount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'นำออกแล้ว $_confirmedCount จาก $_totalCount รายการ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
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
      ),
    );
  }

  // ── Items List ───────────────────────────────
  Widget _buildItemsList() {
    final pending = widget.session.items
        .where((i) => _partStatus[i.partId] == 'PENDING')
        .toList();
    final confirmed = widget.session.items
        .where((i) => _partStatus[i.partId] == 'CONFIRMED')
        .toList();

    return Column(
      children: [
        // Pending
        if (pending.isNotEmpty)
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รอ Confirm',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 12),
                ...pending.map((item) => _buildItemRow(item, false)),
              ],
            ),
          ),

        if (pending.isNotEmpty && confirmed.isNotEmpty)
          const SizedBox(height: 12),

        // Confirmed
        if (confirmed.isNotEmpty)
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirmed แล้ว',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 12),
                ...confirmed.map((item) => _buildItemRow(item, true)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItemRow(UnloadItem item, bool confirmed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confirmed
            ? AppTheme.success.withValues(alpha: 0.05)
            : AppTheme.background,
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
                if (item.lotNumber != null)
                  Text(
                    'Lot: ${item.lotNumber}',
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
                '${item.qty} ชิ้น',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              StatusBadge(item.condition),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepDot(number: 1, label: 'สแกน Pallet', done: true),
        _StepLine(),
        _StepDot(number: 2, label: 'Unload', active: true),
        _StepLine(),
        _StepDot(number: 3, label: 'Load Basket', active: false),
      ],
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
                      color: active ? Colors.white : Colors.grey,
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
