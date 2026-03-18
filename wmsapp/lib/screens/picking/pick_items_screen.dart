// lib/screens/picking/pick_items_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

// ── Screen states ──────────────────────────────────────────────────────────
enum _PickState {
  scanSource, // รอสแกน source pallet (สำหรับรอบถัดไป)
  pickView,   // แสดง station + รายการที่ต้องหยิบ
  scanDest,   // รอสแกน dest (pallet เปล่า)
}

class PickItemsScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String pickOrderId;
  final AssignPickStationResponse initialAssignment;

  const PickItemsScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.pickOrderId,
    required this.initialAssignment,
  });

  @override
  State<PickItemsScreen> createState() => _PickItemsScreenState();
}

class _PickItemsScreenState extends State<PickItemsScreen> {
  final _sourceScanCtrl = TextEditingController();
  final _sourceScanFocus = FocusNode();
  final _destScanCtrl = TextEditingController();
  final _destScanFocus = FocusNode();
  final _api = ApiService();

  _PickState _state = _PickState.pickView; // เริ่มจาก pickView เลย (ได้ assignment มาแล้ว)
  bool _loading = false;

  late String _pickOrderId;
  late AssignPickStationResponse _assignment;

  // qty controllers สำหรับแต่ละ part
  final Map<String, TextEditingController> _qtyCtrl = {};

  @override
  void initState() {
    super.initState();
    _pickOrderId = widget.pickOrderId;
    _assignment = widget.initialAssignment;
    _buildQtyControllers();
  }

  void _buildQtyControllers() {
    _disposeQtyCtrl();
    for (final item in _assignment.palletItems) {
      _qtyCtrl[item.partId] = TextEditingController(
        text: '${item.qtyToPickSuggested}',
      );
    }
  }

  void _disposeQtyCtrl() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    _qtyCtrl.clear();
  }

  // ── Scan source pallet (สำหรับรอบถัดไป) ────
  Future<void> _scanSourcePallet() async {
    final palletId = _sourceScanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.assignPickStation(
      palletId: palletId,
      operatorId: widget.userId,
      pickOrderId: _pickOrderId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'สแกน Pallet ไม่สำเร็จ',
      );
      _sourceScanCtrl.clear();
      _sourceScanFocus.requestFocus();
      return;
    }

    _assignment = result.data!;
    _buildQtyControllers();

    setState(() {
      _state = _PickState.pickView;
    });
  }

  // ── User confirms pick → go to scan dest ──
  void _goToScanDest() {
    setState(() {
      _state = _PickState.scanDest;
      _destScanCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destScanFocus.requestFocus();
    });
  }

  // ── Scan dest pallet → confirm pick ───────
  Future<void> _scanDestAndConfirm() async {
    final destId = _destScanCtrl.text.trim().toUpperCase();
    if (destId.isEmpty) return;

    if (destId == _assignment.palletId) {
      showErrorDialog(
        context,
        message: 'Dest Pallet ต้องไม่ใช่ Source Pallet เดียวกัน',
      );
      return;
    }

    // รวบรวม items ที่จะ pick
    final items = <Map<String, dynamic>>[];
    for (final item in _assignment.palletItems) {
      final qty = int.tryParse(_qtyCtrl[item.partId]?.text.trim() ?? '') ?? 0;
      if (qty > 0) {
        items.add({'partId': item.partId, 'qty': qty});
      }
    }

    if (items.isEmpty) {
      showWarningSnackbar(
        context,
        'กรุณาระบุจำนวนที่จะ pick อย่างน้อย 1 รายการ',
      );
      return;
    }

    setState(() => _loading = true);
    final result = await _api.confirmPickV2(
      pickOrderId: _pickOrderId,
      sourcePalletId: _assignment.palletId,
      destPalletId: destId,
      items: items,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'Confirm pick ไม่สำเร็จ',
      );
      return;
    }

    final res = result.data!;
    final sourcePalletId = _assignment.palletId;

    // ให้ user เลือกส่ง source pallet กลับที่ไหน
    if (!mounted) return;
    await _showReturnPalletDialog(
      sourcePalletId: sourcePalletId,
      isEmpty: res.sourcePalletEmpty,
    );
    if (!mounted) return;

    if (res.isPickOrderComplete) {
      // Pick order ครบ — แสดง dialog แล้วกลับ
      await _showCompleteDialog(res, destId);
      if (mounted) Navigator.pop(context);
      return;
    }

    // ยังไม่ครบ — แสดง summary แล้วเริ่ม loop ใหม่
    await _showCycleDoneDialog(res, destId);
    if (!mounted) return;

    _resetToScanSource();
  }

  // ── Return pallet dialog — เลือกส่งกลับ ASRS หรือ ZONE PACK ──
  Future<void> _showReturnPalletDialog({
    required String sourcePalletId,
    required bool isEmpty,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isEmpty ? Icons.inventory_2_outlined : Icons.inventory_2,
              color: isEmpty ? AppTheme.textGrey : AppTheme.warning,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ส่ง $sourcePalletId กลับ',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEmpty
                  ? 'Pallet ว่างแล้ว — เลือกปลายทาง'
                  : 'Pallet ยังมีของเหลือ — เลือกปลายทาง',
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _returnPallet(sourcePalletId, 'ASRS');
                },
                icon: const Icon(Icons.warehouse, size: 18),
                label: const Text('ส่งกลับ ASRS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _returnPallet(sourcePalletId, 'ZONE_PACK');
                },
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('ส่งไป ZONE PACK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _returnPallet(String palletId, String destination) async {
    setState(() => _loading = true);
    final result = await _api.returnPallet(
      palletId: palletId,
      destination: destination,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ส่ง Pallet กลับไม่สำเร็จ',
      );
    }
  }

  void _resetToScanSource() {
    _disposeQtyCtrl();
    setState(() {
      _state = _PickState.scanSource;
      _sourceScanCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceScanFocus.requestFocus();
    });
  }

  // ── Complete dialog ──────────────────────────────
  Future<void> _showCompleteDialog(
    ConfirmPickResponse res,
    String destId,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            SizedBox(width: 8),
            Text('Pick Order ครบแล้ว!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: 'Pick Order', value: _pickOrderId),
            InfoRow(label: 'Dest Pallet', value: destId),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('กลับหน้าหลัก'),
          ),
        ],
      ),
    );
  }

  // ── Cycle done dialog (ยังไม่ครบ) ────────────────
  Future<void> _showCycleDoneDialog(
    ConfirmPickResponse res,
    String destId,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('Pick รอบนี้เสร็จ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: 'Dest Pallet', value: destId),
            const Divider(height: 16),
            const Text(
              'ยังต้อง Pick เพิ่ม:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...res.remainingItems
                .where((r) => r.remainingQty > 0)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_right,
                          size: 14,
                          color: AppTheme.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${r.partId}: เหลือ ${r.remainingQty} ชิ้น',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan Pallet ต่อ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Back handling ────────────────────────────────
  void _handleBack() {
    if (_state == _PickState.scanDest) {
      // กลับไปแก้ไขจำนวน
      setState(() => _state = _PickState.pickView);
    } else if (_state == _PickState.scanSource) {
      // กลับไปหน้า picking (exit)
      Navigator.pop(context);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _PickState.pickView &&
          _assignment == widget.initialAssignment,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: WmsAppBar(
          title: 'Pick: $_pickOrderId',
          userName: widget.fullName,
        ),
        body: LoadingOverlay(
          loading: _loading,
          message: 'กำลังดำเนินการ...',
          child: switch (_state) {
            _PickState.scanSource => _buildScanSource(),
            _PickState.pickView => _buildPickView(),
            _PickState.scanDest => _buildScanDest(),
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // State 1: Scan Source Pallet (สำหรับรอบถัดไป)
  // ══════════════════════════════════════════════════
  Widget _buildScanSource() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order info
          _buildOrderInfoBanner(),
          const SizedBox(height: 16),

          // Scan card
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'Scan Source Pallet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'สแกน Pallet ถัดไปที่ต้องการ Pick',
                  style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  label: 'Source Pallet ID',
                  hint: 'Scan Pallet ID',
                  controller: _sourceScanCtrl,
                  focusNode: _sourceScanFocus,
                  onSubmit: _scanSourcePallet,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Scan',
                  icon: Icons.search,
                  onPressed: _scanSourcePallet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // State 2: Pick View (station info + items)
  // ══════════════════════════════════════════════════
  Widget _buildPickView() {
    final a = _assignment;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Station info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.success,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.stationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.success,
                      ),
                    ),
                    Text(
                      'Station: ${a.stationId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.palletId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Order remaining needs
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, color: AppTheme.secondary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Pick Order: $_pickOrderId',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...a.pickOrderItems.map(
                  (oi) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_right,
                          size: 14,
                          color: AppTheme.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${oi.partId}: ${oi.itemDesc}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'ต้องการ ${oi.remainingQty}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pallet items (qty editors)
          const Row(
            children: [
              Icon(Icons.inventory_2, color: AppTheme.textPrimary, size: 18),
              SizedBox(width: 6),
              Text(
                'รายการบน Pallet (ระบุจำนวนที่จะหยิบ)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...a.palletItems.map((item) => _buildPalletItemCard(item)),
          const SizedBox(height: 16),

          // Pick done button
          PrimaryButton(
            label: 'หยิบครบแล้ว → สแกน Pallet เปล่า',
            icon: Icons.arrow_forward,
            onPressed: _goToScanDest,
          ),
        ],
      ),
    );
  }

  Widget _buildPalletItemCard(PickItemOnPallet item) {
    final ctrl = _qtyCtrl[item.partId];
    // หา remaining จาก pickOrderItems
    final orderItem = _assignment.pickOrderItems
        .where((oi) => oi.partId == item.partId)
        .firstOrNull;
    final needed = orderItem?.remainingQty ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
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
              Expanded(
                child: Text(
                  item.partId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              StatusBadge(item.condition),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.itemDesc,
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
          Text(
            '${item.owner} / ${item.brand}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
          const Divider(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บน Pallet: ${item.qtyOnPallet}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  if (needed > 0)
                    Text(
                      'ต้องการ: $needed',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              const Text(
                'จำนวนหยิบ: ',
                style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
              ),
              SizedBox(
                width: 72,
                height: 38,
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
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
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // State 3: Scan Dest Pallet
  // ══════════════════════════════════════════════════
  Widget _buildScanDest() {
    final picked = <String, int>{};
    for (final item in _assignment.palletItems) {
      final qty = int.tryParse(_qtyCtrl[item.partId]?.text.trim() ?? '') ?? 0;
      if (qty > 0) picked[item.partId] = qty;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary of what was picked
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'รายการที่หยิบ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...picked.entries.map((e) {
                  final item = _assignment.palletItems.firstWhere(
                    (i) => i.partId == e.key,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${e.key} — ${item.itemDesc}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'x${e.value}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scan dest pallet
          WmsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppTheme.secondary),
                    SizedBox(width: 8),
                    Text(
                      'Scan Pallet เปล่า (ปลายทาง)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'สแกน Pallet เปล่าที่จะใส่สินค้าที่หยิบมา',
                  style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  label: 'Dest Pallet ID',
                  hint: 'Scan Pallet เปล่า',
                  controller: _destScanCtrl,
                  focusNode: _destScanFocus,
                  onSubmit: _scanDestAndConfirm,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'ยืนยัน',
                  icon: Icons.check,
                  onPressed: _scanDestAndConfirm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DangerButton(
            label: 'กลับแก้ไขจำนวน',
            icon: Icons.edit,
            onPressed: () => setState(() => _state = _PickState.pickView),
          ),
        ],
      ),
    );
  }

  // ── Order info banner ────────────────────────────
  Widget _buildOrderInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: AppTheme.primary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Pick Order: $_pickOrderId',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sourceScanCtrl.dispose();
    _sourceScanFocus.dispose();
    _destScanCtrl.dispose();
    _destScanFocus.dispose();
    _disposeQtyCtrl();
    super.dispose();
  }
}
