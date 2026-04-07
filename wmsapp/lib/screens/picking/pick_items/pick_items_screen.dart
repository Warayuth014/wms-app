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
import 'widgets/pick_view/picking_order_needs_card.dart';
import 'widgets/pick_view/picking_station_banner.dart';
import 'widgets/return_source/picking_return_source_actions.dart';
import 'widgets/return_source/picking_return_source_info_card.dart';
import 'widgets/scan_dest/picking_dest_scan_card.dart';
import 'widgets/scan_dest/picking_picked_summary_card.dart';
import 'widgets/scan_source/picking_scan_source_card.dart';
import '../../packing/packing_screen.dart';

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
  final _api = ApiService();

  _PickState _state = _PickState.pickView;
  bool _loading = false;

  late String _pickOrderId;
  late AssignPickStationResponse _assignment;

  String? _destPalletId;
  ConfirmPickResponse? _lastResult;
  String? _returnPalletId;
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
      final qty = int.tryParse(_qtyCtrl[item.partId]?.text.trim() ?? '') ?? 0;
      if (qty > 0) {
        items.add({'partId': item.partId, 'qty': qty});
      }
    }

    if (items.isEmpty) {
      showWarningSnackbar(
        context,
        'กรุณาระบุจำนวนที่จะ Pick อย่างน้อย 1 รายการ',
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
          PickingOrderNeedsCard(
            pickOrderId: _pickOrderId,
            pickOrderItems: assignment.pickOrderItems,
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
          ),
        ],
      ),
    );
  }

  Widget _buildScanDest() {
    final pickedItems = <String, int>{};
    for (final item in _assignment.palletItems) {
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
              onPressed: isComplete && _destPalletId != null
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PackingScreen(
                            userId: widget.userId,
                            fullName: widget.fullName,
                            initialPalletId: _destPalletId,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.local_shipping, size: 20),
              label: Text(
                isComplete
                    ? 'ส่งไป PACK'
                    : 'ส่งไป PACK (เมื่อ Pick ครบเท่านั้น)',
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
    _disposeQtyCtrl();
    super.dispose();
  }
}
