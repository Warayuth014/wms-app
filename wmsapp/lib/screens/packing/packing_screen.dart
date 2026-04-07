// lib/screens/packing/packing_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import 'widgets/packing_scan_card.dart';
import 'widgets/packing_pallet_info_card.dart';
import 'widgets/packing_items_list.dart';
import 'widgets/packing_tracking_card.dart';

enum _PackState { scanPallet, review, success }

class PackingScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String? initialPalletId;

  const PackingScreen({
    super.key,
    required this.userId,
    required this.fullName,
    this.initialPalletId,
  });

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  _PackState _state = _PackState.scanPallet;
  bool _loading = false;
  PackingScanResponse? _pallet;
  ConfirmPackResponse? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPalletId != null &&
          widget.initialPalletId!.isNotEmpty) {
        _scanCtrl.text = widget.initialPalletId!;
        _scanPallet();
      } else {
        _scanFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _scanPallet() async {
    final palletId = _scanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.scanPalletForPacking(palletId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ไม่พบ Pallet',
      );
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    setState(() {
      _pallet = result.data;
      _state = _PackState.review;
    });
  }

  Future<void> _confirmPack() async {
    if (_pallet == null) return;

    setState(() => _loading = true);
    final result = await _api.confirmPack(
      palletId: _pallet!.palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
        context,
        message: result.error ?? 'ยืนยัน Pack ไม่สำเร็จ',
      );
      return;
    }

    setState(() {
      _result = result.data;
      _state = _PackState.success;
    });
  }

  void _resetForNext() {
    setState(() {
      _pallet = null;
      _result = null;
      _scanCtrl.clear();
      _state = _PackState.scanPallet;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Packing', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังประมวลผล...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_state == _PackState.scanPallet) _buildScanPallet(),
                if (_state == _PackState.review) _buildReview(),
                if (_state == _PackState.success) _buildSuccess(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanPallet() {
    return PackingScanCard(
      controller: _scanCtrl,
      focusNode: _scanFocus,
      onScan: _scanPallet,
    );
  }

  Widget _buildReview() {
    final pallet = _pallet!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PackingPalletInfoCard(pallet: pallet),
        const SizedBox(height: 12),
        PackingItemsList(items: pallet.items),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirmPack,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'ยืนยัน Pack',
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
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetForNext,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('ยกเลิก / สแกน Pallet ใหม่'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textGrey(context),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PackingTrackingCard(result: result),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetForNext,
            icon: Icon(MdiIcons.barcodeScan, size: 20),
            label: const Text(
              'Pack Pallet ถัดไป',
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
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('กลับหน้าหลัก'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textGrey(context),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
