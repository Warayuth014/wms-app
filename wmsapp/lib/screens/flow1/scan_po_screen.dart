// lib/screens/flow1/scan_po_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/offline_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/wms_models.dart';
import 'scan_part_screen.dart';

class ScanPoScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const ScanPoScreen({super.key, required this.userId, required this.fullName});

  @override
  State<ScanPoScreen> createState() => _ScanPoScreenState();
}

class _ScanPoScreenState extends State<ScanPoScreen> {
  final _poController = TextEditingController();
  final _api = ApiService();

  POResponse? _po;
  bool _loadingPO = false;
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

  // ── สแกน PO ──────────────────────────────────
  Future<void> _scanPO() async {
    final poId = _poController.text.trim().toUpperCase();
    if (poId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ PO ID');
      return;
    }

    setState(() {
      _loadingPO = true;
      _po = null;
    });

    // ถ้า offline → ดึงจาก cache
    if (!_isOnline) {
      final cached = await OfflineService().getCachedPO(poId);
      setState(() => _loadingPO = false);

      if (!mounted) return;

      if (cached == null) {
        showErrorDialog(
          context,
          message: 'ไม่พบ PO ใน cache กรุณาเชื่อมต่อ WiFi ก่อน',
        );
        return;
      }
      setState(() => _po = cached);
      showWarningSnackbar(context, 'ใช้ข้อมูล offline');
      return;
    }

    // online → ดึงจาก API
    final result = await _api.getPO(poId);
    setState(() => _loadingPO = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() => _po = result.data!);

    // cache ไว้ใช้ตอน offline
    await OfflineService().savePO(result.data!);
  }

  // ── เปิด Session ─────────────────────────────
  Future<void> _openSession() async {
    if (_po == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'เริ่มรับสินค้า',
      message:
          'เริ่มรับสินค้าจาก ${_po!.poId}\n'
          'Supplier: ${_po!.supplierName}',
      confirmLabel: 'เริ่มเลย',
    );
    if (!confirm) return;

    setState(() => _loadingSession = true);

    final result = await _api.openReceivingSession(
      poId: _po!.poId,
      operatorId: widget.userId,
    );

    setState(() => _loadingSession = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    // ไป scan_part_screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanPartScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          session: result.data!,
          po: _po!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Flow 1 — รับสินค้า', userName: widget.fullName),
      body: Column(
        children: [
          if (!_isOnline) const OfflineBanner(pendingCount: 0),

          Expanded(
            child: LoadingOverlay(
              loading: _loadingSession,
              message: 'กำลังเปิด session...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Step Indicator ──────────
                    _buildStepIndicator(),
                    const SizedBox(height: 20),

                    // ── Scan PO ─────────────────
                    WmsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'สแกน PO Invoice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ScanTextField(
                            label: 'PO ID',
                            hint: 'เช่น PO-001',
                            controller: _poController,
                            onSubmit: _scanPO,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'ค้นหา PO',
                            icon: Icons.search,
                            loading: _loadingPO,
                            onPressed: _scanPO,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── PO Result ───────────────
                    if (_po != null) ...[
                      _buildPOInfo(),
                      const SizedBox(height: 16),
                      _buildPOItems(),
                      const SizedBox(height: 16),

                      // ปุ่มเริ่มรับสินค้า
                      if (_po!.status != 'RECEIVED')
                        PrimaryButton(
                          label: 'เริ่มรับสินค้า',
                          icon: Icons.play_arrow,
                          onPressed: _openSession,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.success),
                              SizedBox(width: 8),
                              Text(
                                'PO นี้รับสินค้าครบแล้ว',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
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

  // ── PO Info Card ─────────────────────────────
  Widget _buildPOInfo() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _po!.poId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              StatusBadge(_po!.status),
            ],
          ),
          const Divider(height: 20),
          InfoRow(label: 'Supplier', value: _po!.supplierName),
          InfoRow(label: 'จำนวน Part', value: '${_po!.items.length} รายการ'),
          InfoRow(
            label: 'รับแล้ว',
            value:
                '${_po!.items.where((i) => i.status == 'RECEIVED').length} รายการ',
          ),
        ],
      ),
    );
  }

  // ── PO Items List ────────────────────────────
  Widget _buildPOItems() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายการสินค้า',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ..._po!.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.status == 'RECEIVED'
                      ? AppTheme.success.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // Check icon
                  Icon(
                    item.status == 'RECEIVED'
                        ? Icons.check_circle
                        : item.status == 'PARTIAL'
                        ? Icons.incomplete_circle
                        : Icons.radio_button_unchecked,
                    color: item.status == 'RECEIVED'
                        ? AppTheme.success
                        : item.status == 'PARTIAL'
                        ? Colors.orange
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          item.itemDesc,
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.qtyReceived}/${item.qtyOrdered}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'ชิ้น',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Indicator ───────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepDot(number: 1, label: 'สแกน PO', active: true),
        _StepLine(),
        _StepDot(number: 2, label: 'สแกน Part', active: false),
        _StepLine(),
        _StepDot(number: 3, label: 'สแกน Pallet', active: false),
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
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
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
