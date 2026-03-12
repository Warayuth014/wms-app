// lib/screens/flow2/load_basket_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

class LoadBasketDetailScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final ConfirmedUnloadItem item;
  // ถ้ามีค่า = resume mode (item ถูก load ลง basket แล้ว รอคืนตะกร้า)
  final LoadedBasketItem? preloaded;

  const LoadBasketDetailScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.item,
    this.preloaded,
  });

  @override
  State<LoadBasketDetailScreen> createState() => _LoadBasketDetailScreenState();
}

class _LoadBasketDetailScreenState extends State<LoadBasketDetailScreen>
    with SingleTickerProviderStateMixin {
  final _basketController = TextEditingController();
  final _basketFocus = FocusNode();

  BasketScanResponse? _basket;
  bool _loading = false;
  bool _loaded = false;
  bool _returning = false;

  // animation
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

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

    // Resume mode: item ถูก load แล้ว ข้ามไปหน้า คืนตะกร้า ทันที
    if (widget.preloaded != null) {
      final p = widget.preloaded!;
      _basket = BasketScanResponse(
        basketId: p.basketId,
        label: p.basketLabel,
        zone: null,
        destination: p.basketDestination,
        status: 'IN_USE',
        message: '',
      );
      _loaded = true;
    }
  }

  // ── สแกน Basket ───────────────────────────
  Future<void> _scanBasket() async {
    final basketId = _basketController.text.trim().toUpperCase();
    if (basketId.isEmpty) return;

    setState(() => _loading = true);

    final result = await ApiService().scanBasket(basketId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Basket นี้');
      _basketController.clear();
      _basketFocus.requestFocus();
      return;
    }

    final basket = result.data!;

    // เช็ค Basket ต้องว่างเท่านั้น
    if (basket.status != 'AVAILABLE') {
      showErrorDialog(
        context,
        message:
            'Basket ${basket.basketId} ไม่ว่าง\n'
            'สถานะ: ${basket.status}\n'
            '1 Part ต่อ 1 Basket เท่านั้น',
      );
      _basketController.clear();
      _basketFocus.requestFocus();
      return;
    }

    setState(() => _basket = basket);
  }

  // ── Load เข้า Basket ──────────────────────
  Future<void> _loadToBasket() async {
    if (_basket == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'Load เข้า Basket',
      message:
          'ใส่ ${widget.item.partId} เข้า ${_basket!.label}?\n'
          '${widget.item.itemDesc}\n'
          'จำนวน: ${widget.item.qtyUnloaded} ชิ้น',
      confirmLabel: 'Load',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await ApiService().loadToBasketIndependent(
      unloadLineId: widget.item.lineId,
      basketId: _basket!.basketId,
      partId: widget.item.partId,
      palletId: widget.item.palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'Load ไม่สำเร็จ');
      return;
    }

    setState(() => _loaded = true);
    showSuccessSnackbar(context, 'Load สำเร็จ');
  }

  // ── คืนตะกร้า (Robot pickup animation) ───
  Future<void> _returnBasket() async {
    setState(() => _returning = true);

    // Call API + animation พร้อมกัน
    final result = await Future.wait([
      ApiService().returnBasket(
        basketId: _basket!.basketId,
        operatorId: widget.userId,
      ),
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (!mounted) return;
    setState(() => _returning = false);

    final apiResult = result[0] as ApiResult<Map<String, dynamic>>;
    if (!apiResult.success) {
      showErrorDialog(
        context,
        message: apiResult.error ?? 'คืนตะกร้าไม่สำเร็จ',
      );
      return;
    }

    showSuccessSnackbar(context, 'คืนตะกร้าเรียบร้อย');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _basketController.dispose();
    _basketFocus.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        appBar: WmsAppBar(title: 'Load Basket', userName: widget.fullName),
        body: _returning
            ? _buildReturnAnimation()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Part Info ─────────────
                    _buildPartInfo(),
                    const SizedBox(height: 20),

                    // ── Scan Basket ───────────
                    if (!_loaded) ...[
                      const Text(
                        'สแกน Basket',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ScanTextField(
                        controller: _basketController,
                        label: 'Basket ID เช่น BKT-A1',
                        hint: 'BKT-A1',
                        onSubmit: _scanBasket,
                      ),
                    ],

                    // ── Basket Info ───────────
                    if (_basket != null) ...[
                      const SizedBox(height: 16),
                      _buildBasketInfo(),
                      const SizedBox(height: 20),

                      // ── Load Button ───────────
                      if (!_loaded)
                        PrimaryButton(
                          label: 'Load เข้า Basket',
                          icon: Icons.add_box,
                          onPressed: _loadToBasket,
                        ),
                    ],

                    // ── Return Basket Button ──
                    if (_loaded) ...[
                      const SizedBox(height: 20),
                      _buildLoadedSuccess(),
                      const SizedBox(height: 20),
                      DangerButton(
                        label: 'คืนตะกร้า',
                        icon: Icons.arrow_upward,
                        onPressed: _returnBasket,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  // ── Part Info Card ─────────────────────────
  Widget _buildPartInfo() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.item.partId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'สินค้า', value: widget.item.itemDesc),
          InfoRow(label: 'Pallet', value: widget.item.palletId),
          InfoRow(label: 'จำนวน', value: '${widget.item.qtyUnloaded} ชิ้น'),
          if (widget.item.lotNumber != null)
            InfoRow(label: 'Lot', value: widget.item.lotNumber!),
        ],
      ),
    );
  }

  // ── Basket Info Card ───────────────────────
  Widget _buildBasketInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_basket, color: AppTheme.success, size: 28),
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
                    color: AppTheme.success,
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

  // ── Loaded Success Card ────────────────────
  Widget _buildLoadedSuccess() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Load สำเร็จแล้ว',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                Text(
                  '${widget.item.partId} → ${_basket!.label}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Return Animation (5 วิ) ────────────────
  Widget _buildReturnAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ลูกศรสีแดงชี้ขึ้น
          AnimatedBuilder(
            animation: _arrowAnimation,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _arrowAnimation.value),
              child: const Icon(
                Icons.arrow_upward,
                color: AppTheme.danger,
                size: 80,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Icon(Icons.shopping_basket, color: AppTheme.textGrey, size: 48),
          const SizedBox(height: 24),
          const Text(
            'Robot กำลังรับตะกร้า...',
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
    );
  }
}

// ── Countdown Timer Widget ─────────────────
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
        color: AppTheme.danger,
      ),
    );
  }
}
