// lib/screens/picking/pick_items/pick_items_screen.dart

import 'package:flutter/material.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/part_thumbnail.dart';
import 'widgets/after_pick/picking_after_pick_success_banner.dart';
import 'widgets/after_pick/picking_remaining_items_card.dart';
import 'widgets/pick_view/picking_dest_pallet_banner.dart';
import 'widgets/pick_view/picking_order_info_banner.dart';
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
  final _sourceScanCtrl = TextEditingController();
  final _sourceScanFocus = FocusNode();
  final _destScanCtrl = TextEditingController();
  final _destScanFocus = FocusNode();
  final _partScanCtrl = TextEditingController();
  final _partScanFocus = FocusNode();
  final _api = ApiService();

  _PickState _state = _PickState.pickView;
  bool _loading = false;

  late String _pickOrderId;
  late AssignPickStationResponse _assignment;

  String? _destPalletId;
  ConfirmPickResponse? _lastResult;
  String? _returnPalletId;
  final Set<String> _selectedPartIds = {};
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
    _selectedPartIds.clear();
    for (final item in _assignment.palletItems) {
      // เริ่มต้น qty = 0 → ผู้ใช้ต้องเลือก Part ก่อน
      _qtyCtrl[item.partId] = TextEditingController(text: '0');
    }
  }

  void _disposeQtyCtrl() {
    for (final controller in _qtyCtrl.values) {
      controller.dispose();
    }
    _qtyCtrl.clear();
  }

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
      setState(() {
        _returnPalletId = palletId;
        _state = _PickState.returnSource;
      });
      return;
    }

    _assignment = result.data!;
    _buildQtyControllers();

    setState(() {
      _state = _PickState.pickView;
    });
  }

  void _scanPart() {
    final partId = _partScanCtrl.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    final match = _assignment.palletItems
        .where((item) => item.partId == partId)
        .firstOrNull;

    if (match == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" บน Pallet นี้');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    setState(() {
      // เลือก Part อัตโนมัติ + เติม qty ที่แนะนำ
      if (!_selectedPartIds.contains(partId)) {
        _selectedPartIds.add(partId);
        _qtyCtrl[partId]?.text = '${match.qtyToPickSuggested}';
      }
    });
    _partScanCtrl.clear();
    _partScanFocus.requestFocus();
  }

  void _togglePartSelection(String partId) {
    final item = _assignment.palletItems
        .where((i) => i.partId == partId)
        .firstOrNull;
    if (item == null) return;

    setState(() {
      if (_selectedPartIds.contains(partId)) {
        _selectedPartIds.remove(partId);
        _qtyCtrl[partId]?.text = '0';
      } else {
        _selectedPartIds.add(partId);
        _qtyCtrl[partId]?.text = '${item.qtyToPickSuggested}';
      }
    });
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
      if (!_selectedPartIds.contains(item.partId)) continue;
      final qty = int.tryParse(_qtyCtrl[item.partId]?.text.trim() ?? '') ?? 0;
      if (qty > 0) {
        items.add({'partId': item.partId, 'qty': qty});
      }
    }

    if (items.isEmpty) {
      showWarningSnackbar(
        context,
        'กรุณาเลือก Part ที่จะ Pick อย่างน้อย 1 รายการ',
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
    _disposeQtyCtrl();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickingStationBanner(assignment: assignment),
          const SizedBox(height: 12),
          // ── สแกน Part ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _partScanCtrl,
                    focusNode: _partScanFocus,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'สแกน Part',
                      hintText: 'กรุณา barcode →',
                      prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _scanPart(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanPart,
                  icon: const Icon(Icons.send, color: AppTheme.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: AppTheme.textPrimary(context),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'รายการบน Pallet (ระบุจำนวนที่จะ Pick)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...assignment.palletItems.map(_buildPalletItemCard),
          const SizedBox(height: 16),
          PrimaryButton(
            label: hasDest
                ? 'ยืนยัน Pick ไปยัง $_destPalletId'
                : 'สแกน Pallet ปลายทางเพื่อยืนยัน',
            icon: hasDest ? Icons.check : Icons.arrow_forward,
            onPressed: _goToScanDestOrConfirm,
          ),
        ],
      ),
    );
  }

  Widget _buildPalletItemCard(PickItemOnPallet item) {
    final controller = _qtyCtrl[item.partId];
    final orderItem = _assignment.pickOrderItems
        .where((pickOrderItem) => pickOrderItem.partId == item.partId)
        .firstOrNull;
    final needed = orderItem?.remainingQty ?? 0;
    final isSelected = _selectedPartIds.contains(item.partId);

    return GestureDetector(
      onTap: () => _togglePartSelection(item.partId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border(context),
            width: isSelected ? 2 : 1,
          ),
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
                // Checkbox เลือก Part
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _togglePartSelection(item.partId),
                    activeColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
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
                        fontSize: 13, color: AppTheme.textGrey(context)),
                  ),
                  Row(
                    children: [
                      if (item.lotNumber != null &&
                          item.lotNumber!.isNotEmpty) ...[
                        Icon(
                          Icons.label_outline,
                          size: 12,
                          color: AppTheme.textGrey(context),
                        ),
                        const SizedBox(width: 2),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textGrey(context),
                            ),
                            children: [
                              const TextSpan(
                                text: 'Batch No.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' : ${item.lotNumber}'),
                            ],
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
                ],
              ),
            ),
            const Divider(height: 14),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คงเหลือบน Pallet: ${item.qtyOnPallet}',
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
                if (isSelected) ...[
                  Text(
                    'จำนวนที่หยิบ: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey(context),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    height: 38,
                    child: TextField(
                      controller: controller,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanDest() {
    final pickedItems = <String, int>{};
    for (final item in _assignment.palletItems) {
      if (!_selectedPartIds.contains(item.partId)) continue;
      final qty = int.tryParse(_qtyCtrl[item.partId]?.text.trim() ?? '') ?? 0;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickingAfterPickSuccessBanner(
            isComplete: isComplete,
            destPalletId: _destPalletId,
          ),
          const SizedBox(height: 16),
          if (!isComplete) ...[
            PickingRemainingItemsCard(remainingItems: result.remainingItems),
            const SizedBox(height: 16),
          ],
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
    _disposeQtyCtrl();
    super.dispose();
  }
}
