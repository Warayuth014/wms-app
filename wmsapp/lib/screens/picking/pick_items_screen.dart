// lib/screens/picking/pick_items_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import '../../widgets/part_thumbnail.dart';

// ── Screen states ──────────────────────────────────────────────────────────
enum _PickState {
  scanSource, // รอสแกน source pallet
  pickView, // แสดง station + รายการที่ต้องหยิบ
  scanDest, // รอสแกน dest (pallet เปล่า) — ครั้งแรกเท่านั้น
  afterPick, // หลัง confirm pick — แสดง 2 ปุ่ม
  returnSource, // pallet ไม่มีของ pick → เลือก ASRS / ZONE PACK หรือออก
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

  _PickState _state = _PickState.pickView;
  bool _loading = false;

  late String _pickOrderId;
  late AssignPickStationResponse _assignment;

  // dest pallet จำไว้ใช้ซ้ำในรอบถัดไป
  String? _destPalletId;

  // ผลลัพธ์จาก confirm pick ล่าสุด
  ConfirmPickResponse? _lastResult;

  // pallet ที่สแกนแล้วไม่มี pick items (สำหรับ returnSource state)
  String? _returnPalletId;

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

  // ══════════════════════════════════════════════════
  // Actions
  // ══════════════════════════════════════════════════

  // ── Scan source pallet ─────────────────────────
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
      // ไม่มีของ pick บน pallet นี้ → ถือว่าเป็น pallet ที่ไม่เกี่ยว / ว่าง
      // ให้เลือกส่ง ASRS / ZONE PACK หรือออก
      setState(() {
        _returnPalletId = palletId;
        _state = _PickState.returnSource;
      });
      return;
    }

    _assignment = result.data!;
    _buildQtyControllers();

    // ถ้ามี pick items → ไป pickView (ใช้ dest pallet เดิมถ้ามี)
    setState(() {
      _state = _PickState.pickView;
    });
  }

  // ── User confirms pick qty → ไปสแกน dest หรือ confirm เลย ──
  void _goToScanDestOrConfirm() {
    if (_destPalletId != null) {
      // มี dest pallet แล้ว → confirm เลย
      _confirmPick(_destPalletId!);
    } else {
      // ยังไม่มี dest pallet → ไปสแกน
      setState(() {
        _state = _PickState.scanDest;
        _destScanCtrl.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _destScanFocus.requestFocus();
      });
    }
  }

  // ── Scan dest pallet → confirm pick ──────────
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

    _destPalletId = destId;
    await _confirmPick(destId);
  }

  // ── Confirm pick (โอนของจาก source → dest) ────
  Future<void> _confirmPick(String destId) async {
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

    setState(() {
      _lastResult = result.data!;
      _state = _PickState.afterPick;
    });
  }

  // ── Return pallet to ASRS / ZONE PACK ──────────
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
      return;
    }

    showSuccessSnackbar(context, 'ส่ง $palletId ไป $destination แล้ว');
    _goToScanSource();
  }

  // ── Go to scan source state ──────────────────
  void _goToScanSource() {
    _disposeQtyCtrl();
    setState(() {
      _state = _PickState.scanSource;
      _sourceScanCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceScanFocus.requestFocus();
    });
  }

  // ── Back handling ──────────────────────────────
  void _handleBack() {
    switch (_state) {
      case _PickState.scanDest:
        setState(() => _state = _PickState.pickView);
      case _PickState.afterPick:
        // ไม่ให้กด back ตอนอยู่ afterPick → ต้องเลือกปุ่ม
        break;
      case _PickState.returnSource:
        _goToScanSource();
      case _PickState.scanSource:
        Navigator.pop(context);
      case _PickState.pickView:
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _state == _PickState.pickView &&
          _assignment == widget.initialAssignment,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: WmsAppBar(
          title: 'Pick: $_pickOrderId',
          userName: widget.fullName,
        ),
        body: SafeArea(
          top: false,
          child: LoadingOverlay(
            loading: _loading,
            message: 'กำลังดำเนินการ...',
            child: switch (_state) {
              _PickState.scanSource => _buildScanSource(),
              _PickState.pickView => _buildPickView(),
              _PickState.scanDest => _buildScanDest(),
              _PickState.afterPick => _buildAfterPick(),
              _PickState.returnSource => _buildReturnSource(),
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // State 1: Scan Source Pallet
  // ══════════════════════════════════════════════════
  Widget _buildScanSource() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOrderInfoBanner(),
          if (_destPalletId != null) ...[
            const SizedBox(height: 8),
            _buildDestPalletBanner(),
          ],
          const SizedBox(height: 16),

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
                Text(
                  'สแกน Pallet ที่ต้องการหยิบของออก',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textGrey(context),
                  ),
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
    final hasDest = _destPalletId != null;

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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
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
                    const Icon(
                      Icons.assignment,
                      color: AppTheme.secondary,
                      size: 18,
                    ),
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
                        Icon(
                          Icons.arrow_right,
                          size: 14,
                          color: AppTheme.textGrey(context),
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
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: AppTheme.textPrimary(context),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'รายการบน Pallet (ระบุจำนวนที่จะหยิบ)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...a.palletItems.map((item) => _buildPalletItemCard(item)),
          const SizedBox(height: 16),

          // Button — ถ้ามี dest pallet แล้วก็ confirm เลย ไม่ต้องสแกนใหม่
          PrimaryButton(
            label: hasDest
                ? 'ยืนยันหยิบ → ใส่ $_destPalletId'
                : 'หยิบครบแล้ว → สแกน Pallet ปลายทาง',
            icon: hasDest ? Icons.check : Icons.arrow_forward,
            onPressed: _goToScanDestOrConfirm,
          ),
        ],
      ),
    );
  }

  Widget _buildPalletItemCard(PickItemOnPallet item) {
    final ctrl = _qtyCtrl[item.partId];
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
        border: Border.all(color: AppTheme.border(context)),
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
              PartThumbnail(imageUrl: item.imageUrl, size: 40),
              const SizedBox(width: 10),
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
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
          ),
          Row(
            children: [
              if (item.lotNumber != null && item.lotNumber!.isNotEmpty) ...[
                Icon(
                  Icons.label_outline,
                  size: 12,
                  color: AppTheme.textGrey(context),
                ),
                const SizedBox(width: 2),
                Text(
                  'Batch No.: ${item.lotNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${item.owner} / ${item.brand}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textGrey(context),
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บน Pallet: ${item.qtyOnPallet}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey(context),
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
              Text(
                'จำนวนหยิบ: ',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textGrey(context),
                ),
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
  // State 3: Scan Dest Pallet (ครั้งแรก)
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
                      'Scan Pallet ปลายทาง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'สแกน Pallet ปลายทางที่จะใส่สินค้าที่หยิบมา',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                const SizedBox(height: 12),
                ScanTextField(
                  label: 'Dest Pallet ID',
                  hint: 'Scan Pallet ปลายทาง',
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

  // ══════════════════════════════════════════════════
  // State 4: After Pick — 2 ปุ่ม
  // ══════════════════════════════════════════════════
  Widget _buildAfterPick() {
    final res = _lastResult!;
    final isComplete = res.isPickOrderComplete;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isComplete ? Icons.celebration : Icons.check_circle,
                  color: AppTheme.success,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  isComplete ? 'Pick Order ครบแล้ว!' : 'Pick รอบนี้สำเร็จ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dest Pallet: $_destPalletId',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Remaining items (ถ้ายังไม่ครบ)
          if (!isComplete) ...[
            WmsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: AppTheme.warning,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ยังต้อง Pick เพิ่ม',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...res.remainingItems
                      .where((r) => r.remainingQty > 0)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_right,
                                size: 14,
                                color: AppTheme.textGrey(context),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${r.partId}: ${r.itemDesc}',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'เหลือ ${r.remainingQty}',
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
            const SizedBox(height: 16),
          ],

          // ── ปุ่ม 1: กลับสแกน Pallet ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goToScanSource,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text(
                'กลับสแกน Pallet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── ปุ่ม 2: ส่งไป PACK ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isComplete
                  ? () {
                      // TODO: ไปหน้า PACK flow
                      showSuccessSnackbar(
                        context,
                        'Pick Order $_pickOrderId ครบ — พร้อมส่งไป PACK',
                      );
                      Navigator.pop(context);
                    }
                  : null,
              icon: const Icon(Icons.local_shipping, size: 20),
              label: Text(
                isComplete ? 'ส่งไป PACK' : 'ส่งไป PACK (รอ Pick ครบก่อน)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.textGrey(
                  context,
                ).withValues(alpha: 0.3),
                disabledForegroundColor: AppTheme.textGrey(context),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // State 5: Return Source — pallet ไม่มี pick items
  // ══════════════════════════════════════════════════
  Widget _buildReturnSource() {
    final palletId = _returnPalletId ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOrderInfoBanner(),
          if (_destPalletId != null) ...[
            const SizedBox(height: 8),
            _buildDestPalletBanner(),
          ],
          const SizedBox(height: 16),

          // Pallet info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.warning,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  palletId,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ไม่มีสินค้าที่ต้อง Pick บน Pallet นี้',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'เลือกปลายทาง',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // ส่งกลับ ASRS
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _returnPallet(palletId, 'ASRS'),
              icon: const Icon(Icons.warehouse, size: 20),
              label: const Text(
                'ส่งกลับ ASRS',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ส่งไป ZONE PACK
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _returnPallet(palletId, 'ZONE_PACK'),
              icon: const Icon(Icons.local_shipping, size: 20),
              label: const Text(
                'ส่งไป ZONE PACK',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Banners ──────────────────────────────────────
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

  Widget _buildDestPalletBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: AppTheme.secondary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Dest Pallet: $_destPalletId',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.secondary,
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
