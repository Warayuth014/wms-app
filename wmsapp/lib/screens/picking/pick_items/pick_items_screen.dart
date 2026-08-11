// lib/screens/picking/pick_items/pick_items_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/part_thumbnail.dart';
import 'widgets/after_pick/picking_after_pick_success_banner.dart';
import 'widgets/after_pick/picking_remaining_items_card.dart';
import 'widgets/pick_view/picking_dest_pallet_banner.dart';
import 'widgets/pick_view/picking_order_info_banner.dart';
import 'widgets/pick_view/picking_order_needs_card.dart';
import 'widgets/pick_view/picking_station_banner.dart';
import 'widgets/return_source/picking_return_source_actions.dart';
import 'widgets/return_source/picking_return_source_info_card.dart';
import 'widgets/scan_dest/picking_dest_scan_card.dart';
import 'widgets/scan_dest/picking_picked_summary_card.dart';
import 'widgets/scan_source/picking_scan_source_card.dart';

enum _PickState {
  scanSource,
  pickView,
  scanDest,
  afterPick,
  returnSource,
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
  static const Color _pickBorder = Color(0xFFDCE6F2);
  static const Color _pickTextDark = Color(0xFF1F2937);
  static const Color _pickTextMuted = Color(0xFF6B7280);
  static const Color _pickChipBg = Color(0xFFEAF3FF);
  static const Color _pickSuccess = Color(0xFF22A06B);
  static const double _pickSerialHeaderHeight = 32;
  static const double _pickSerialRowHeight = 42;
  static const int _pickSerialVisibleRowLimit = 5;

  final _sourceScanCtrl = TextEditingController();
  final _sourceScanFocus = FocusNode();
  final _destScanCtrl = TextEditingController();
  final _destScanFocus = FocusNode();
  final _partScanCtrl = TextEditingController();
  final _partScanFocus = FocusNode();
  final _serialScanCtrl = TextEditingController();
  final _serialScanFocus = FocusNode();
  final _qtyEntryCtrl = TextEditingController();
  final _qtyEntryFocus = FocusNode();
  final _api = ApiService();

  _PickState _state = _PickState.pickView;
  bool _loading = false;

  late String _pickOrderId;
  late AssignPickStationResponse _assignment;

  String? _destPalletId;
  ConfirmPickResponse? _lastResult;
  String? _returnPalletId;
  final Set<String> _selectedPartIds = {};
  final Map<String, List<String>> _pickedSerials = {};
  final Map<String, int> _pickedQty = {};
  final Set<String> _expandedSerialPartIds = {};

  @override
  void initState() {
    super.initState();
    _pickOrderId = widget.pickOrderId;
    _assignment = widget.initialAssignment;
    _resetPickedSerials();
  }

  void _resetPickedSerials() {
    _selectedPartIds.clear();
    _pickedSerials.clear();
    _pickedQty.clear();
    _expandedSerialPartIds.clear();
    _qtyEntryCtrl.clear();
    for (final item in _assignment.palletItems) {
      _pickedSerials[item.partId] = <String>[];
    }
  }

  /// จำนวนที่หยิบแล้วของ part นี้ — จาก S/N ที่สแกน (ถ้า require) หรือจำนวนที่กรอกตรง (ถ้าไม่ require)
  int _pickedCountFor(PickItemOnPallet item) => item.serialRequire
      ? (_pickedSerials[item.partId]?.length ?? 0)
      : (_pickedQty[item.partId] ?? 0);

  PickItemOnPallet? get _currentItem {
    if (_selectedPartIds.length != 1) return null;
    final partId = _selectedPartIds.first;
    return _assignment.palletItems.where((i) => i.partId == partId).firstOrNull;
  }

  /// เลือก part นี้ให้ active (single-select) — ถ้ามี S/N ต้อง scan, ถ้าไม่มีให้กรอกจำนวนตรงๆ
  void _activatePart(String partId) {
    final item = _assignment.palletItems.where((i) => i.partId == partId).firstOrNull;
    if (item == null) return;

    setState(() {
      _selectedPartIds
        ..clear()
        ..add(partId);
      _partScanCtrl.text = partId;
      if (!item.serialRequire) {
        final remaining = item.qtyToPickSuggested - (_pickedQty[partId] ?? 0);
        _qtyEntryCtrl.text = remaining > 0 ? '$remaining' : '0';
      }
    });

    if (item.serialRequire) {
      _serialScanFocus.requestFocus();
    } else {
      _qtyEntryFocus.requestFocus();
    }
  }

  void _scanPartField() {
    final partId = _partScanCtrl.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    final item = _assignment.palletItems.where((i) => i.partId == partId).firstOrNull;
    if (item == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" บน Pallet นี้');
      return;
    }
    _activatePart(partId);
  }

  void _addQty() {
    final item = _currentItem;
    if (item == null) {
      showWarningSnackbar(context, 'กรุณาสแกน Part ก่อน');
      _partScanFocus.requestFocus();
      return;
    }

    final qty = int.tryParse(_qtyEntryCtrl.text.trim());
    if (qty == null || qty <= 0) {
      showWarningSnackbar(context, 'กรุณาระบุจำนวน');
      _qtyEntryFocus.requestFocus();
      return;
    }
    if (qty > item.qtyToPickSuggested) {
      showErrorDialog(
        context,
        message: 'จำนวนเกินที่ต้องการ Pick (สูงสุด ${item.qtyToPickSuggested})',
      );
      return;
    }

    setState(() => _pickedQty[item.partId] = qty);
    showSuccessSnackbar(context, 'Part ${item.partId} ระบุจำนวน $qty ชิ้น');
  }

  Future<void> _scanSourcePallet() async {
    final palletId = _sourceScanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.assignPickStation(
      palletId: palletId,
      pickOrderId: _pickOrderId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() {
        _returnPalletId = palletId;
        _state = _PickState.returnSource;
      });
      return;
    }

    _assignment = result.data!;
    _resetPickedSerials();

    setState(() {
      _state = _PickState.pickView;
    });
  }

  void _scanSerial() {
    final partId = _partScanCtrl.text.trim().toUpperCase();
    final serialNo = _serialScanCtrl.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showWarningSnackbar(context, 'กรุณาสแกน Part ก่อน');
      _partScanFocus.requestFocus();
      return;
    }
    if (serialNo.isEmpty) {
      showWarningSnackbar(context, 'กรุณาสแกน S/N');
      _serialScanFocus.requestFocus();
      return;
    }

    final match = _assignment.palletItems
        .where((item) => item.partId == partId)
        .firstOrNull;

    if (match == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" บน Pallet นี้');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    final serials = _pickedSerials.putIfAbsent(partId, () => <String>[]);
    if (serials.contains(serialNo)) {
      showWarningSnackbar(context, 'S/N "$serialNo" สแกนไปแล้ว');
      _serialScanCtrl.clear();
      _serialScanFocus.requestFocus();
      return;
    }

    if (!match.availableSerials.contains(serialNo)) {
      showErrorDialog(
        context,
        message: 'S/N "$serialNo" ไม่อยู่บน Pallet นี้สำหรับ Part "$partId"',
      );
      _serialScanCtrl.clear();
      _serialScanFocus.requestFocus();
      return;
    }

    if (serials.length >= match.qtyToPickSuggested) {
      showWarningSnackbar(
        context,
        'Part $partId สแกนครบ ${match.qtyToPickSuggested} ชิ้นแล้ว',
      );
      _serialScanCtrl.clear();
      _serialScanFocus.requestFocus();
      return;
    }

    setState(() {
      _selectedPartIds.add(partId);
      serials.add(serialNo);
    });
    _serialScanCtrl.clear();
    _serialScanFocus.requestFocus();
  }

  /// แบนเนอร์ "ดูทั้งหมด" ที่ขึ้นเมื่อ filter อยู่ — แตะเพื่อเคลียร์ selection
  Widget _buildShowAllBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() {
          _selectedPartIds.clear();
          _partScanCtrl.clear();
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'แสดงเฉพาะ part ที่เลือก',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              Text(
                'ดูทั้งหมด',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.close, size: 14, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _selectPartForScan(String partId) {
    final item = _assignment.palletItems
        .where((i) => i.partId == partId)
        .firstOrNull;
    if (item == null) return;

    if (_selectedPartIds.contains(partId)) {
      // tap ตัวที่ select อยู่ → deselect (กลับไปดูทั้งหมด)
      setState(() {
        _selectedPartIds.remove(partId);
        if (_partScanCtrl.text == partId) _partScanCtrl.clear();
      });
      return;
    }
    _activatePart(partId);
  }

  void _removePickedSerial(String partId, String serialNo) {
    setState(() {
      final serials = _pickedSerials[partId];
      serials?.remove(serialNo);
      if (serials == null || serials.isEmpty) {
        _selectedPartIds.remove(partId);
        _expandedSerialPartIds.remove(partId);
      }
    });
    _serialScanFocus.requestFocus();
  }

  void _togglePickedSerials(String partId) {
    setState(() {
      if (_expandedSerialPartIds.contains(partId)) {
        _expandedSerialPartIds.remove(partId);
      } else {
        _expandedSerialPartIds.add(partId);
      }
    });
  }

  Future<void> _copyAndFillSerialForTest(
    String partId,
    String serialNo,
  ) async {
    await Clipboard.setData(ClipboardData(text: serialNo));
    if (!mounted) return;
    setState(() {
      _partScanCtrl.text = partId;
      _serialScanCtrl.text = serialNo;
    });
    _serialScanFocus.requestFocus();
    showSuccessSnackbar(context, 'คัดลอก S/N "$serialNo" แล้ว');
  }

  void _showAvailableSerialsSheet() {
    final itemsWithSerials = _assignment.palletItems
        .where((item) => item.availableSerials.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'S/N สำหรับทดสอบ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'ปิด',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: itemsWithSerials.isEmpty
                          ? Center(
                              child: Text(
                                'ยังไม่มี S/N บน Pallet นี้',
                                style: TextStyle(
                                  color: AppTheme.textGrey(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: itemsWithSerials.length,
                              itemBuilder: (context, index) {
                                final item = itemsWithSerials[index];
                                final picked = _pickedSerials[item.partId] ??
                                    const <String>[];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.partId,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${picked.length}/${item.qtyToPickSuggested}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...item.availableSerials.map((serialNo) {
                                        final alreadyPicked =
                                            picked.contains(serialNo);
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: alreadyPicked
                                                ? AppTheme.success
                                                    .withValues(alpha: 0.12)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: alreadyPicked
                                                  ? AppTheme.success
                                                      .withValues(alpha: 0.28)
                                                  : AppTheme.border(context),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  serialNo,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: alreadyPicked
                                                        ? AppTheme.success
                                                        : AppTheme.textPrimary(
                                                            context,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              if (alreadyPicked)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Text(
                                                    'เลือกแล้ว',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppTheme.success,
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(
                                                width: 40,
                                                height: 40,
                                                child: IconButton(
                                                  tooltip: 'คัดลอก/ใช้',
                                                  padding: EdgeInsets.zero,
                                                  iconSize: 18,
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      sheetContext,
                                                    );
                                                    _copyAndFillSerialForTest(
                                                      item.partId,
                                                      serialNo,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.content_copy,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _goToScanDestOrConfirm() {
    if (_destPalletId != null) {
      _confirmPick(_destPalletId!);
      return;
    }

    setState(() {
      _state = _PickState.scanDest;
      _destScanCtrl.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destScanFocus.requestFocus();
    });
  }

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

  Future<void> _confirmPick(String destId) async {
    final items = <Map<String, dynamic>>[];
    for (final item in _assignment.palletItems) {
      final qty = _pickedCountFor(item);
      if (qty <= 0) continue;

      items.add({
        'partId': item.partId,
        'qty': qty,
        // สินค้าไม่มี S/N ส่ง [] ไป backend จะเช็คด้วย Part.SerialRequire เอง
        'serialNumbers': item.serialRequire
            ? (_pickedSerials[item.partId] ?? const <String>[])
            : const <String>[],
      });
    }

    if (items.isEmpty) {
      showWarningSnackbar(
        context,
        'กรุณาสแกน S/N หรือระบุจำนวนที่จะ Pick อย่างน้อย 1 รายการ',
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
        message: result.error ?? 'Confirm Pick ไม่สำเร็จ',
      );
      return;
    }

    setState(() {
      _lastResult = result.data!;
      _state = _PickState.afterPick;
    });
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
      return;
    }

    showSuccessSnackbar(context, 'ส่ง $palletId ไป $destination แล้ว');
    _goToScanSource();
  }

  void _goToScanSource() {
    _resetPickedSerials();
    setState(() {
      _state = _PickState.scanSource;
      _sourceScanCtrl.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceScanFocus.requestFocus();
    });
  }

  Future<void> _sendToPack(String palletId) async {
    setState(() => _loading = true);
    final result = await _api.sendToPack(palletId: palletId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ส่งไป PACK ไม่สำเร็จ');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.data?['message'] ?? 'ส่งไป PACK สำเร็จ'),
        backgroundColor: AppTheme.success,
      ),
    );

    // กลับไปสแกน source ต่อ (ยังอยู่หน้า Pick)
    setState(() => _destPalletId = null);
    _goToScanSource();
  }

  void _handleBack() {
    switch (_state) {
      case _PickState.scanDest:
        setState(() => _state = _PickState.pickView);
        break;
      case _PickState.afterPick:
        break;
      case _PickState.returnSource:
        _goToScanSource();
        break;
      case _PickState.scanSource:
      case _PickState.pickView:
        Navigator.pop(context);
        break;
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
            message: 'กำลังประมวลผล...',
            child: Column(
              children: [
                Expanded(
                  child: switch (_state) {
                    _PickState.scanSource => _buildScanSource(),
                    _PickState.pickView => _buildPickView(),
                    _PickState.scanDest => _buildScanDest(),
                    _PickState.afterPick => _buildAfterPick(),
                    _PickState.returnSource => _buildReturnSource(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanSource() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickingOrderInfoBanner(pickOrderId: _pickOrderId),
        if (_destPalletId != null) ...[
          const SizedBox(height: 8),
          PickingDestPalletBanner(destPalletId: _destPalletId!),
        ],
        const SizedBox(height: 16),
        PickingScanSourceCard(
          controller: _sourceScanCtrl,
          focusNode: _sourceScanFocus,
          onScan: _scanSourcePallet,
        ),
      ],
    ),
  );

  Widget _buildPickView() {
    final assignment = _assignment;
    final hasDest = _destPalletId != null;
    final totalNeeded = assignment.palletItems.fold<int>(
      0,
      (sum, item) => sum + item.qtyToPickSuggested,
    );
    final totalPicked = assignment.palletItems.fold<int>(
      0,
      (sum, item) => sum + _pickedCountFor(item),
    );

    // filter ตาม select + sort: expanded ขึ้นล่างสุด
    final visibleItems = assignment.palletItems
        .where((i) =>
            _selectedPartIds.isEmpty ||
            _selectedPartIds.contains(i.partId))
        .toList()
      ..sort((a, b) {
        final ae = _expandedSerialPartIds.contains(a.partId) ? 1 : 0;
        final be = _expandedSerialPartIds.contains(b.partId) ? 1 : 0;
        return ae.compareTo(be);
      });

    return Column(
      children: [
        // ── Sticky top: station + order need + scanner ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickingStationBanner(assignment: assignment),
              const SizedBox(height: 12),
              PickingOrderNeedsCard(
                pickOrderId: _pickOrderId,
                pickOrderItems: assignment.pickOrderItems,
              ),
              const SizedBox(height: 12),
              _buildPickScannerCard(),
              const SizedBox(height: 14),
              _buildPalletListHeader(totalPicked, totalNeeded),
              const SizedBox(height: 8),
              if (_selectedPartIds.isNotEmpty) _buildShowAllBanner(),
            ],
          ),
        ),
        // ── Scrollable: part list เท่านั้น ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: visibleItems.map(_buildPalletItemCard).toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            border: Border(
              top: BorderSide(color: Color(0xFFE4EAF2)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: totalPicked > 0 ? _goToScanDestOrConfirm : null,
                icon: Icon(hasDest ? Icons.check : Icons.arrow_forward_rounded),
                label: Text(
                  totalPicked == 0
                      ? 'สแกนสินค้าก่อนยืนยัน'
                      : hasDest
                          ? 'ยืนยันไป $_destPalletId'
                          : 'ยืนยัน Pallet ปลายทาง',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.25),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickScannerCard() {
    final activeItem = _currentItem;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _pickCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สแกน Part',
            style: TextStyle(
              fontSize: 12,
              color: _pickTextMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _partScanCtrl,
            focusNode: _partScanFocus,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Part No.',
              hintText: 'เช่น PT-1001',
              prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _pickBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 1.5,
                ),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _scanPartField(),
          ),
          const SizedBox(height: 12),
          // สินค้าไม่มี S/N → กรอกจำนวนตรงๆ แทนการสแกน S/N
          if (activeItem != null && !activeItem.serialRequire) ...[
            const Text(
              'ระบุจำนวนที่หยิบ',
              style: TextStyle(
                fontSize: 12,
                color: _pickTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyEntryCtrl,
              focusNode: _qtyEntryFocus,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'จำนวน',
                hintText: 'สูงสุด ${activeItem.qtyToPickSuggested}',
                prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _pickBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _addQty(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _addQty,
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'ยืนยันจำนวน',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'สแกน S/N',
              style: TextStyle(
                fontSize: 12,
                color: _pickTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _serialScanCtrl,
              focusNode: _serialScanFocus,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Serial Number',
                hintText: 'กรอกหรือสแกน S/N สินค้า',
                prefixIcon: const Icon(Icons.confirmation_number, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _pickBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _scanSerial(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _scanSerial,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'เพิ่ม S/N',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _pickCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _pickBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildPalletListHeader(int totalPicked, int totalNeeded) {
    return Row(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          color: _pickTextDark,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'รายการบน Pallet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _pickTextDark,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _pickChipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'สแกนแล้ว $totalPicked/$totalNeeded',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: 'แสดง S/N สำหรับทดสอบ',
          visualDensity: VisualDensity.compact,
          onPressed: _showAvailableSerialsSheet,
          icon: Icon(
            Icons.visibility_outlined,
            size: 20,
            color: AppTheme.textGrey(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPalletItemCard(PickItemOnPallet item) {
    final orderItem = _assignment.pickOrderItems
        .where((pickOrderItem) => pickOrderItem.partId == item.partId)
        .firstOrNull;
    final needed = orderItem == null ? 0 : item.qtyToPickSuggested;
    final pickedSerials = _pickedSerials[item.partId] ?? const <String>[];
    final pickedQty = _pickedCountFor(item);
    final isSelected = pickedQty > 0 || _selectedPartIds.contains(item.partId);
    final isComplete = pickedQty >= needed && needed > 0;
    final progress = needed > 0 ? (pickedQty / needed).clamp(0.0, 1.0) : 0.0;
    final showSerials = _expandedSerialPartIds.contains(item.partId);
    final selectedColor = isComplete ? _pickSuccess : AppTheme.primary;
    final bodyTextColor = isSelected ? _pickTextDark : _pickTextMuted;

    return GestureDetector(
      onTap: () => _selectPartForScan(item.partId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.55)
                : _pickBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: selectedColor),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(isSelected ? 18 : 12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? selectedColor
                              : AppTheme.textGrey(context),
                          size: isSelected ? 24 : 22,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemDesc,
                          style: TextStyle(
                            fontSize: 13,
                            color: bodyTextColor,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        Row(
                          children: [
                            if (item.lotNumber != null &&
                                item.lotNumber!.isNotEmpty) ...[
                              Icon(
                                Icons.label_outline,
                                size: 12,
                                color: bodyTextColor,
                              ),
                              const SizedBox(width: 2),
                              Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: bodyTextColor,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Batch No.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: ' : ${item.lotNumber}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                '${item.owner} / ${item.brand}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: bodyTextColor,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'คงเหลือบน Pallet: ${item.qtyOnPallet}',
                              style: TextStyle(
                                fontSize: 13,
                                color: bodyTextColor,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (needed > 0)
                              Text(
                                'ต้องการ: $needed',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.warning,
                                ),
                              ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: item.availableSerials.isEmpty
                            ? null
                            : () => _togglePickedSerials(item.partId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isComplete
                                ? _pickSuccess.withValues(alpha: 0.12)
                                : _pickChipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$pickedQty/$needed',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isComplete
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
                              if (item.availableSerials.isNotEmpty) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  showSerials
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isComplete
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation(_pickSuccess),
                    ),
                  ),
                  if (showSerials) ...[
                    const SizedBox(height: 8),
                    _buildSerialTable(
                      partId: item.partId,
                      availableSerials: item.availableSerials,
                      pickedSerials: pickedSerials,
                      actionColor: selectedColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง S/N pool ทั้งหมดของ part บน pallet + highlight อันที่ scan แล้ว
  /// - Picked: bg เขียวอ่อน + ✓ icon + text เขียวเข้ม
  /// - Unpicked: bg ขาว + text grey
  /// - Tap row ที่ picked = ยกเลิก scan (ลบออก)
  Widget _buildSerialTable({
    required String partId,
    required List<String> availableSerials,
    required List<String> pickedSerials,
    required Color actionColor,
  }) {
    final pickedSet = pickedSerials.toSet();
    // Sort: unpicked อยู่บน, picked ไปท้าย (เรียงตามลำดับที่สแกน)
    final sortedSerials = <String>[
      ...availableSerials.where((s) => !pickedSet.contains(s)),
      ...pickedSerials.where((s) => availableSerials.contains(s)),
    ];
    final total = sortedSerials.length;
    final picked = pickedSet.length;
    final visibleRows = total > _pickSerialVisibleRowLimit
        ? _pickSerialVisibleRowLimit
        : total;
    final rowCount = visibleRows == 0 ? 1 : visibleRows;

    return Container(
      height: _pickSerialHeaderHeight + (rowCount * _pickSerialRowHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _pickBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header ──
          Container(
            height: _pickSerialHeaderHeight,
            color: const Color(0xFFF3F7FC),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 34,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _pickTextMuted,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'S/N',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _pickTextMuted,
                    ),
                  ),
                ),
                Text(
                  'สแกนแล้ว $picked/$total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: picked > 0 ? _pickSuccess : _pickTextMuted,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          // ── Rows ──
          Expanded(
            child: total == 0
                ? const Center(
                    child: Text(
                      'ไม่มี S/N pool',
                      style: TextStyle(
                          fontSize: 12,
                          color: _pickTextMuted,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemExtent: _pickSerialRowHeight,
                    physics: total > _pickSerialVisibleRowLimit
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: total,
                    itemBuilder: (context, index) {
                      final serialNo = sortedSerials[index];
                      final isPicked = pickedSet.contains(serialNo);
                      final isLast = index == total - 1;

                      return InkWell(
                        onTap: isPicked
                            ? () => _removePickedSerial(partId, serialNo)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isPicked
                                ? _pickSuccess.withValues(alpha: 0.10)
                                : Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: isLast
                                    ? Colors.transparent
                                    : _pickBorder,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPicked
                                        ? _pickSuccess
                                        : _pickTextMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  serialNo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPicked
                                        ? _pickSuccess
                                        : _pickTextDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 42,
                                height: _pickSerialRowHeight,
                                child: isPicked
                                    ? Icon(Icons.check_circle,
                                        size: 18, color: _pickSuccess)
                                    : Icon(
                                        Icons.radio_button_unchecked,
                                        size: 16,
                                        color: AppTheme.textGrey(context)
                                            .withValues(alpha: 0.4),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanDest() {
    final pickedItems = <String, int>{};
    for (final item in _assignment.palletItems) {
      final qty = _pickedSerials[item.partId]?.length ?? 0;
      if (qty > 0) pickedItems[item.partId] = qty;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickingPickedSummaryCard(
            pickedItems: pickedItems,
            palletItems: _assignment.palletItems,
          ),
          const SizedBox(height: 16),
          PickingDestScanCard(
            controller: _destScanCtrl,
            focusNode: _destScanFocus,
            onConfirm: _scanDestAndConfirm,
            pickOrderId: _pickOrderId,
          ),
          const SizedBox(height: 12),
          DangerButton(
            label: 'กลับไปแก้จำนวนที่หยิบ',
            icon: Icons.edit,
            onPressed: () => setState(() => _state = _PickState.pickView),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterPick() {
    final result = _lastResult!;
    final isComplete = result.isPickOrderComplete;
    final remaining = result.remainingItems
        .where((item) => item.remainingQty > 0)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickingAfterPickSuccessBanner(
            isComplete: isComplete,
            destPalletId: _destPalletId,
          ),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 12),
            PickingRemainingItemsCard(remainingItems: remaining),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goToScanSource,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text(
                'กลับไปสแกน Source Pallet',
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _destPalletId != null
                  ? () => _sendToPack(_destPalletId!)
                  : null,
              icon: const Icon(Icons.local_shipping, size: 20),
              label: Text(
                'ส่งไป PACK',
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

  Widget _buildReturnSource() {
    final palletId = _returnPalletId ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickingOrderInfoBanner(pickOrderId: _pickOrderId),
          if (_destPalletId != null) ...[
            const SizedBox(height: 8),
            PickingDestPalletBanner(destPalletId: _destPalletId!),
          ],
          const SizedBox(height: 16),
          PickingReturnSourceInfoCard(palletId: palletId),
          const SizedBox(height: 20),
          PickingReturnSourceActions(
            palletId: palletId,
            onReturn: (destination) => _returnPallet(palletId, destination),
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
    _partScanCtrl.dispose();
    _partScanFocus.dispose();
    _serialScanCtrl.dispose();
    _serialScanFocus.dispose();
    _qtyEntryCtrl.dispose();
    _qtyEntryFocus.dispose();
    super.dispose();
  }
}
