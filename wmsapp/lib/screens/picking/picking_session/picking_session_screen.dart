// lib/screens/picking/picking_session/picking_session_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../pick_items/pick_items_screen.dart';
import 'widgets/picking_scan_card.dart';

class PickingSessionScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PickingSessionScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PickingSessionScreen> createState() => _PickingSessionScreenState();
}

class _PickingSessionScreenState extends State<PickingSessionScreen> {
  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
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
  }

  Future<void> _showReturnOrErrorDialog(
    String palletId,
    String? errorMsg,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.warning, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(palletId, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMsg ?? 'ไม่มีสินค้าที่ต้อง Pick บน Pallet นี้',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textGrey(context),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ต้องการส่ง Pallet กลับหรือไม่?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _returnPallet(palletId, 'ASRS');
                },
                icon: Icon(MdiIcons.warehouse, size: 18),
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
                  Navigator.pop(dialogContext);
                  _returnPallet(palletId, 'ZONE_PACK');
                },
                icon: Icon(MdiIcons.truckDeliveryOutline, size: 18),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textGrey(context),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('ปิด'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanPallet() async {
    final palletId = _scanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.assignPickStation(
      palletId: palletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      if (result.isNotFound) {
        showErrorDialog(
          context,
          message: result.error ?? 'ไม่พบ Pallet',
        );
      } else {
        await _showReturnOrErrorDialog(palletId, result.error);
      }
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    final assignment = result.data!;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickItemsScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          pickOrderId: assignment.pickOrderId,
          initialAssignment: assignment,
        ),
      ),
    ).then((_) {
      _scanCtrl.clear();
      _scanFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Picking', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังค้นหา...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PickingScanCard(
                  controller: _scanCtrl,
                  focusNode: _scanFocus,
                  onScan: _scanPallet,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
