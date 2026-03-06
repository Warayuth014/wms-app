// lib/screens/flow2/load_basket_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/offline_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/wms_models.dart';

class LoadBasketScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final UnloadSession session;
  final PalletScanResponse pallet;

  const LoadBasketScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.session,
    required this.pallet,
  });

  @override
  State<LoadBasketScreen> createState() => _LoadBasketScreenState();
}

class _LoadBasketScreenState extends State<LoadBasketScreen> {
  final _basketController = TextEditingController();
  final _partController = TextEditingController();
  final _api = ApiService();

  BasketScanResponse? _basket;
  bool _loadingBasket = false;
  bool _loadingLoad = false;
  bool _isOnline = true;

  // track status แต่ละ Part
  // key = partId, value = PENDING | LOADED
  late Map<String, String> _partStatus;

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

  int get _loadedCount => _partStatus.values.where((s) => s == 'LOADED').length;

  int get _totalCount => _partStatus.length;

  bool get _allLoaded => _loadedCount == _totalCount;

  // ── สแกน Basket ───────────────────────────────
  Future<void> _scanBasket() async {
    final basketId = _basketController.text.trim().toUpperCase();
    if (basketId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Basket ID');
      return;
    }

    setState(() {
      _loadingBasket = true;
      _basket = null;
    });

    final result = await _api.scanBasket(basketId);
    setState(() => _loadingBasket = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() => _basket = result.data!);
    showSuccessSnackbar(
      context,
      '✅ ${_basket!.label} — ${_basket!.destination ?? "ไม่ระบุปลายทาง"}',
    );
  }

  // ── Load Part เข้า Basket ─────────────────────
  Future<void> _loadPart() async {
    if (_basket == null) {
      showErrorDialog(context, message: 'กรุณาสแกน Basket ก่อน');
      return;
    }

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

    // ตรวจว่า load ไปแล้วหรือยัง
    if (_partStatus[partId] == 'LOADED') {
      showWarningSnackbar(context, 'Part $partId load ไปแล้ว');
      _partController.clear();
      return;
    }

    final item = widget.session.items.firstWhere((i) => i.partId == partId);

    final confirm = await showConfirmDialog(
      context,
      title: 'Load เข้า Basket',
      message:
          'ใส่ ${item.partId} เข้า ${_basket!.label}?\n'
          '${item.itemDesc}\n'
          'จำนวน: ${item.qty} ชิ้น\n'
          'ปลายทาง: ${_basket!.destination ?? "-"}',
      confirmLabel: 'Load',
    );
    if (!confirm) return;

    setState(() => _loadingLoad = true);

    // offline → queue
    if (!_isOnline) {
      await OfflineService().addToQueue(
        action: 'load-to-basket',
        data: {
          'sessionId': widget.session.sessionId,
          'basketId': _basket!.basketId,
          'partId': partId,
          'palletId': widget.pallet.palletId,
          'operatorId': widget.userId,
        },
      );

      setState(() {
        _loadingLoad = false;
        _partStatus[partId] = 'LOADED';
        _partController.clear();
      });

      if (!mounted) return;

      showWarningSnackbar(context, 'บันทึกแบบ offline');

      if (_allLoaded) _showCompletedDialog();
      return;
    }

    // online → API
    final result = await _api.loadToBasket(
      sessionId: widget.session.sessionId,
      basketId: _basket!.basketId,
      partId: partId,
      palletId: widget.pallet.palletId,
      operatorId: widget.userId,
    );

    setState(() => _loadingLoad = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() {
      _partStatus[partId] = 'LOADED';
      _partController.clear();
    });

    final allLoaded = result.data!['allLoaded'] as bool;

    showSuccessSnackbar(
      context,
      '✅ $partId loaded ($_loadedCount/$_totalCount)',
    );

    if (allLoaded) {
      await Future.delayed(const Duration(milliseconds: 500));
      _showCompletedDialog();
    }
  }

  // ── Session Completed Dialog ──────────────────
  Future<void> _showCompletedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            SizedBox(width: 8),
            Text(
              'Unload เสร็จสิ้น',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: 'Pallet', value: widget.pallet.palletId),
            InfoRow(label: 'Basket', value: _basket!.label),
            InfoRow(label: 'ปลายทาง', value: _basket!.destination ?? '-'),
            InfoRow(label: 'รายการ', value: '$_totalCount Part'),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.inventory_2, color: AppTheme.success, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Pallet กลับเป็น AVAILABLE แล้ว',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // กลับไปหน้า scan pallet
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Step 2 — Load Basket',
        userName: widget.fullName,
      ),
      body: Column(
        children: [
          if (!_isOnline) const OfflineBanner(pendingCount: 0),

          // ── Progress Bar ────────────────────
          _buildProgressBar(),

          Expanded(
            child: LoadingOverlay(
              loading: _loadingLoad,
              message: 'กำลัง load...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Step Indicator ──────────
                    _buildStepIndicator(),
                    const SizedBox(height: 16),

                    // ── Basket Scan ─────────────
                    WmsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'สแกน Basket',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ScanTextField(
                            label: 'Basket ID',
                            hint: 'เช่น BKT-A1',
                            controller: _basketController,
                            onSubmit: _scanBasket,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'สแกน Basket',
                            icon: Icons.shopping_basket,
                            loading: _loadingBasket,
                            onPressed: _scanBasket,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Basket Info ─────────────
                    if (_basket != null) ...[
                      _buildBasketInfo(),
                      const SizedBox(height: 16),

                      // ── Load Part ───────────────
                      WmsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'สแกน Part เพื่อ Load',
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
                              onSubmit: _loadPart,
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'Load เข้า Basket',
                              icon: Icons.add_box,
                              onPressed: _loadPart,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Items List ──────────────
                    _buildItemsList(),
                    const SizedBox(height: 16),

                    // ── Manual Complete ─────────
                    if (_allLoaded)
                      PrimaryButton(
                        label: 'เสร็จสิ้น ✅',
                        icon: Icons.check_circle,
                        onPressed: _showCompletedDialog,
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

  // ── Basket Info ──────────────────────────────
  Widget _buildBasketInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_basket,
            color: AppTheme.secondary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _basket!.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.secondary,
                  ),
                ),
                Text(
                  _basket!.destination ?? 'ไม่ระบุปลายทาง',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(_basket!.status),
        ],
      ),
    );
  }

  // ── Progress Bar ─────────────────────────────
  Widget _buildProgressBar() {
    final progress = _totalCount == 0 ? 0.0 : _loadedCount / _totalCount;

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
                'Load แล้ว $_loadedCount จาก $_totalCount รายการ',
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
                  color: AppTheme.secondary,
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
                _allLoaded ? AppTheme.success : AppTheme.secondary,
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
    final loaded = widget.session.items
        .where((i) => _partStatus[i.partId] == 'LOADED')
        .toList();

    return Column(
      children: [
        if (pending.isNotEmpty)
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รอ Load',
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

        if (pending.isNotEmpty && loaded.isNotEmpty) const SizedBox(height: 12),

        if (loaded.isNotEmpty)
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Load แล้ว',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 12),
                ...loaded.map((item) => _buildItemRow(item, true)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItemRow(UnloadItem item, bool loaded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: loaded
            ? AppTheme.success.withValues(alpha: 0.05)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: loaded
              ? AppTheme.success.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            loaded ? Icons.check_circle : Icons.radio_button_unchecked,
            color: loaded ? AppTheme.success : Colors.grey,
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
        _StepDot(number: 2, label: 'Unload', done: true),
        _StepLine(),
        _StepDot(number: 3, label: 'Load Basket', active: true),
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
