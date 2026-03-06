// lib/screens/flow2/scan_pallet_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/wms_models.dart';
import 'unload_screen.dart';

class ScanPalletScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const ScanPalletScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<ScanPalletScreen> createState() => _ScanPalletScreenState();
}

class _ScanPalletScreenState extends State<ScanPalletScreen> {
  final _palletController = TextEditingController();
  final _api = ApiService();

  PalletScanResponse? _pallet;
  bool _loadingPallet = false;
  bool _loadingLabeling = false;
  bool _loadingSession = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService().checkNow();
    setState(() => _isOnline = online);
  }

  // ── สแกน Pallet ──────────────────────────────
  Future<void> _scanPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      return;
    }

    if (!_isOnline) {
      showErrorDialog(
        context,
        message: 'Flow 2 ต้องการ WiFi ครับ กรุณาเชื่อมต่อก่อน',
      );
      return;
    }

    setState(() {
      _loadingPallet = true;
      _pallet = null;
    });

    final result = await _api.scanPalletForUnload(palletId);
    setState(() => _loadingPallet = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() => _pallet = result.data!);

    // แจ้งเตือน PW
    if (_pallet!.needsLabeling) {
      showWarningSnackbar(context, '⚠️ Pallet นี้ต้องติดสติ๊กเกอร์ก่อน');
    }
  }

  // ── Confirm Labeling (PW → FG) ────────────────
  Future<void> _confirmLabeling() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'ยืนยันการติดสติ๊กเกอร์',
      message:
          'ติดสติ๊กเกอร์ที่ Pallet ${_pallet!.palletId} เรียบร้อยแล้ว?\n'
          'ระบบจะเปลี่ยนสถานะจาก PW → FG',
      confirmLabel: 'ยืนยัน',
    );
    if (!confirm) return;

    setState(() => _loadingLabeling = true);

    final result = await _api.confirmLabeling(
      palletId: _pallet!.palletId,
      operatorId: widget.userId,
    );

    setState(() => _loadingLabeling = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    showSuccessSnackbar(
      context,
      '✅ เปลี่ยนสถานะเป็น FG แล้ว กรุณาสแกน Pallet ใหม่',
    );

    // scan ใหม่
    setState(() => _pallet = null);
    await _scanPallet();
  }

  // ── เปิด Unload Session ───────────────────────
  Future<void> _openUnloadSession() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'เริ่ม Unload',
      message:
          'เริ่มนำสินค้าออกจาก Pallet ${_pallet!.palletId}?\n'
          'มีสินค้า ${_pallet!.items.length} รายการ',
      confirmLabel: 'เริ่มเลย',
    );
    if (!confirm) return;

    setState(() => _loadingSession = true);

    final result = await _api.openUnloadSession(
      palletId: _pallet!.palletId,
      operatorId: widget.userId,
    );

    setState(() => _loadingSession = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnloadScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          session: result.data!,
          pallet: _pallet!,
        ),
      ),
    ).then((_) {
      // reset หลังกลับมา
      setState(() {
        _pallet = null;
        _palletController.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Flow 2 — Unload', userName: widget.fullName),
      body: Column(
        children: [
          if (!_isOnline) const OfflineBanner(pendingCount: 0),

          Expanded(
            child: LoadingOverlay(
              loading: _loadingSession || _loadingLabeling,
              message: _loadingLabeling
                  ? 'กำลังอัปเดตสถานะ...'
                  : 'กำลังเปิด session...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Step Indicator ──────────
                    _buildStepIndicator(),
                    const SizedBox(height: 20),

                    // ── Scan Pallet ─────────────
                    WmsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'สแกน Pallet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ScanTextField(
                            label: 'Pallet ID',
                            hint: 'เช่น PAL-001',
                            controller: _palletController,
                            onSubmit: _scanPallet,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'ค้นหา Pallet',
                            icon: Icons.search,
                            loading: _loadingPallet,
                            onPressed: _scanPallet,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Pallet Result ───────────
                    if (_pallet != null) ...[
                      _buildPalletInfo(),
                      const SizedBox(height: 16),

                      // ── PW Alert ───────────────
                      if (_pallet!.needsLabeling) ...[
                        _buildPWAlert(),
                        const SizedBox(height: 16),
                      ],

                      // ── Items List ─────────────
                      _buildItemsList(),
                      const SizedBox(height: 16),

                      // ── Action Button ──────────
                      if (_pallet!.needsLabeling)
                        PrimaryButton(
                          label: 'ติดสติ๊กเกอร์แล้ว ✅',
                          icon: Icons.label,
                          onPressed: _confirmLabeling,
                        )
                      else
                        PrimaryButton(
                          label: 'เริ่ม Unload',
                          icon: Icons.output,
                          onPressed: _openUnloadSession,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pallet Info Card ──────────────────────────
  Widget _buildPalletInfo() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _pallet!.palletId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              StatusBadge(_pallet!.status),
            ],
          ),
          const Divider(height: 20),
          InfoRow(label: 'ประเภท', value: _pallet!.type),
          InfoRow(label: 'สินค้า', value: '${_pallet!.items.length} รายการ'),
          InfoRow(label: 'สถานะ', value: _pallet!.message),
        ],
      ),
    );
  }

  // ── PW Alert ─────────────────────────────────
  Widget _buildPWAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: AppTheme.warning, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ต้องติดสติ๊กเกอร์ก่อน',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pallet นี้เป็นประเภท PW\nกรุณาส่งไปจุด Labeling\nแล้วกดยืนยันเมื่อติดสติ๊กเกอร์เรียบร้อย',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Items List ───────────────────────────────
  Widget _buildItemsList() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายการสินค้าบน Pallet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ..._pallet!.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.partId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${item.qty} ชิ้น',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(item.condition),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.owner} · ${item.itemDesc}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  if (item.lotNumber != null || item.expiredDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.lotNumber != null)
                          _InfoChip(icon: Icons.tag, label: item.lotNumber!),
                        if (item.expiredDate != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.calendar_today,
                            label: item.expiredDate!,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepDot(number: 1, label: 'สแกน Pallet', active: true),
        _StepLine(),
        _StepDot(number: 2, label: 'Unload', active: false),
        _StepLine(),
        _StepDot(number: 3, label: 'Load Basket', active: false),
      ],
    );
  }
}

// ── Info Chip ─────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textGrey),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
        ),
      ],
    );
  }
}

// ── Step Widgets ──────────────────────────────
class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool active;

  const _StepDot({
    required this.number,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primary : Colors.grey.shade300;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
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
            color: active ? AppTheme.primary : Colors.grey,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
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
