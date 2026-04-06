// lib/screens/unload/unload_session/unload_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import 'widgets/lists/unload_items_list.dart';
import 'widgets/pallet/unload_pallet_info_card.dart';
import 'widgets/scan/unload_pallet_scan_section.dart';
import 'widgets/scan/unload_part_scan_section.dart';
import 'widgets/status/unload_progress_bar.dart';
import 'widgets/status/unload_return_animation.dart';

class UnloadScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const UnloadScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<UnloadScreen> createState() => _UnloadScreenState();
}

class _UnloadScreenState extends State<UnloadScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowController;
  late final Animation<double> _arrowAnimation;

  final _palletController = TextEditingController();
  final _palletFocus = FocusNode();
  final _partController = TextEditingController();
  final _partFocus = FocusNode();

  PalletScanResponse? _pallet;
  int? _sessionId;
  bool _loading = false;
  bool _sessionOpen = false;
  bool _returning = false;
  String? _scannedPartId;

  final Map<String, String> _partStatus = {};
  final Map<String, TextEditingController> _qtyCtrl = {};

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(
      begin: 0,
      end: -20,
    ).animate(
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
    _disposeQtyControllers();
    super.dispose();
  }

  int get _confirmedCount =>
      _partStatus.values.where((status) => status == 'CONFIRMED').length;

  int get _totalCount => _partStatus.length;

  bool get _allConfirmed => _totalCount > 0 && _confirmedCount == _totalCount;

  void _buildQtyControllers() {
    _disposeQtyControllers();
    if (_pallet == null) return;

    for (final item in _pallet!.items) {
      _qtyCtrl[item.partId] = TextEditingController(text: '${item.qty}');
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
    final result = await ApiService().scanPalletForUnload(palletId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ไม่พบ Pallet นี้',
      );
      _palletController.clear();
      _palletFocus.requestFocus();
      return;
    }

    setState(() => _pallet = result.data);

    if (_pallet!.needsLabeling) {
      await _showLabelingDialog();
      return;
    }

    await _openSession();
  }

  Future<void> _showLabelingDialog() async {
    final pallet = _pallet;
    if (pallet == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'ต้องติดสติกเกอร์',
      message:
          'Pallet ${pallet.palletId} เป็นประเภท PW\n'
          'กรุณาส่งไปจุด Labeling ก่อน\n'
          'แล้วกดยืนยันเมื่อติดเรียบร้อย',
      confirmLabel: 'ติดแล้ว ยืนยัน',
    );

    if (!confirm || !mounted) return;

    setState(() => _loading = true);
    final result = await ApiService().confirmLabeling(
      palletId: pallet.palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'เกิดข้อผิดพลาด',
      );
      return;
    }

    showSuccessSnackbar(context, 'เปลี่ยนเป็น FG แล้ว');
    await _openSession();
  }

  Future<void> _openSession() async {
    final pallet = _pallet;
    if (pallet == null) return;

    setState(() => _loading = true);
    final result = await ApiService().openUnloadSession(
      palletId: pallet.palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'เปิด session ไม่ได้',
      );
      return;
    }

    final session = result.data!;
    setState(() {
      _sessionId = session.sessionId;
      _sessionOpen = true;
      _scannedPartId = null;
      _partStatus.clear();
      _pallet = PalletScanResponse(
        palletId: pallet.palletId,
        type: pallet.type,
        status: pallet.status,
        needsLabeling: false,
        items: session.items,
        message: pallet.message,
      );

      for (final item in session.items) {
        _partStatus[item.partId] =
            session.confirmedPartIds.contains(item.partId)
            ? 'CONFIRMED'
            : 'PENDING';
      }
    });

    _buildQtyControllers();
    _partFocus.requestFocus();
  }

  void _scanPart() {
    final partId = _partController.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    if (!_partStatus.containsKey(partId)) {
      showErrorDialog(
        context,
        message: 'Part $partId ไม่อยู่ใน Pallet นี้',
      );
      _partController.clear();
      return;
    }

    if (_partStatus[partId] == 'CONFIRMED') {
      showWarningSnackbar(context, 'Part $partId ยืนยันไปแล้ว');
      _partController.clear();
      return;
    }

    setState(() {
      _scannedPartId = partId;
      _partController.clear();
    });
  }

  Future<void> _confirmScannedPart() async {
    final pallet = _pallet;
    final sessionId = _sessionId;
    final partId = _scannedPartId;
    if (pallet == null || sessionId == null || partId == null) return;

    final qtyText = _qtyCtrl[partId]?.text.trim() ?? '';
    final qty = int.tryParse(qtyText) ?? 0;

    if (qty <= 0) {
      showErrorDialog(
        context,
        message: 'กรุณาระบุจำนวนที่ต้องการ Unload',
      );
      return;
    }

    final item = pallet.items.firstWhere((entry) => entry.partId == partId);
    if (qty > item.qty) {
      showErrorDialog(
        context,
        message: 'จำนวนเกินที่มีบน Pallet (${item.qty})',
      );
      return;
    }

    setState(() => _loading = true);
    final result = await ApiService().confirmUnload(
      sessionId: sessionId,
      palletId: pallet.palletId,
      partId: partId,
      operatorId: widget.userId,
      qtyUnloaded: qty,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'เกิดข้อผิดพลาด',
      );
      return;
    }

    final remainder = item.qty - qty;

    setState(() {
      _scannedPartId = null;

      if (remainder > 0) {
        final index = pallet.items.indexWhere((entry) => entry.partId == partId);
        if (index >= 0) {
          final updatedItems = List<UnloadItem>.from(pallet.items);
          updatedItems[index] = UnloadItem(
            partId: item.partId,
            owner: item.owner,
            brand: item.brand,
            itemDesc: item.itemDesc,
            imageUrl: item.imageUrl,
            lotNumber: item.lotNumber,
            expiredDate: item.expiredDate,
            qty: remainder,
            condition: item.condition,
          );
          _pallet = PalletScanResponse(
            palletId: pallet.palletId,
            type: pallet.type,
            status: pallet.status,
            needsLabeling: pallet.needsLabeling,
            items: updatedItems,
            message: pallet.message,
          );
          _qtyCtrl[partId]?.text = '$remainder';
        }
        _partStatus[partId] = 'PENDING';
      } else {
        _partStatus[partId] = 'CONFIRMED';
      }
    });

    showSuccessSnackbar(
      context,
      remainder > 0
          ? '$partId หยิบ $qty ชิ้น (เหลือ $remainder)'
          : '$partId ครบ $qty ชิ้น ($_confirmedCount/$_totalCount)',
    );

    _partFocus.requestFocus();

    if (_allConfirmed) {
      await _showNextPalletDialog();
    }
  }

  Future<void> _returnPallet() async {
    final pallet = _pallet;
    if (pallet == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'คืน Pallet',
      message:
          'คืน Pallet ${pallet.palletId}\n'
          'ให้โฟล์คลิฟท์อัตโนมัติรับกลับ ASRS?\n\n'
          '(หยิบออกแล้ว $_confirmedCount/$_totalCount รายการ)',
      confirmLabel: 'คืน Pallet',
    );

    if (!confirm || !mounted) return;

    setState(() => _returning = true);
    final results = await Future.wait([
      ApiService().returnPalletToAsis(
        palletId: pallet.palletId,
        sessionId: _sessionId,
        operatorId: widget.userId,
      ),
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (!mounted) return;
    setState(() => _returning = false);

    final result = results.first as ApiResult<Map<String, dynamic>>;
    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'เกิดข้อผิดพลาด',
      );
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
      _pallet = null;
      _sessionId = null;
      _sessionOpen = false;
      _scannedPartId = null;
      _partStatus.clear();
      _palletController.clear();
      _partController.clear();
    });
    _palletFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_returning) {
      return UnloadReturnAnimation(
        userName: widget.fullName,
        arrowAnimation: _arrowAnimation,
      );
    }

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
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_sessionOpen) ...[
                  _buildProgressBar(),
                  const SizedBox(height: 16),
                ],
                if (!_sessionOpen) _buildPalletScanSection(),
                if (_pallet != null) _buildPalletInfoSection(),
                if (_sessionOpen) _buildPartScanSection(),
                if (_partStatus.isNotEmpty) _buildItemsList(),
                if (_scannedPartId != null) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'ยืนยัน Unload: $_scannedPartId',
                    icon: Icons.check,
                    onPressed: _confirmScannedPart,
                  ),
                  const SizedBox(height: 8),
                  DangerButton(
                    label: 'ยกเลิก',
                    icon: Icons.close,
                    onPressed: () {
                      setState(() => _scannedPartId = null);
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
                      side: const BorderSide(
                        color: AppTheme.danger,
                        width: 1.5,
                      ),
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
      ),
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
        pallet: _pallet!,
        sessionId: _sessionId,
        confirmedCount: _confirmedCount,
        totalCount: _totalCount,
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _buildPartScanSection() => UnloadPartScanSection(
    controller: _partController,
    onSubmit: _scanPart,
  );

  Widget _buildProgressBar() => UnloadProgressBar(
    confirmedCount: _confirmedCount,
    totalCount: _totalCount,
    allConfirmed: _allConfirmed,
  );

  Widget _buildItemsList() => UnloadItemsList(
    items: _pallet!.items,
    partStatus: _partStatus,
    qtyControllers: _qtyCtrl,
    scannedPartId: _scannedPartId,
  );
}
