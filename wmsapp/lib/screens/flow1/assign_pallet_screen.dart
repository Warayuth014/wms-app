// lib/screens/flow1/assign_pallet_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/offline_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/wms_models.dart';

class AssignPalletScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final ReceivingSession session;
  final POResponse po;
  final List<ReceiptLineResponse> scannedLines;
  final Function(List<int>) onAssigned;

  const AssignPalletScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.session,
    required this.po,
    required this.scannedLines,
    required this.onAssigned,
  });

  @override
  State<AssignPalletScreen> createState() => _AssignPalletScreenState();
}

class _AssignPalletScreenState extends State<AssignPalletScreen> {
  final _palletController = TextEditingController();
  final _api = ApiService();

  // Part ที่เลือกจะผูกกับ pallet นี้
  final Set<int> _selectedLineIds = {};

  String _palletType = 'FG';
  bool _loading = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // เลือกทุก Part เป็น default
    _selectedLineIds.addAll(widget.scannedLines.map((l) => l.lineId));
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService().checkNow();
    setState(() => _isOnline = online);
  }

  // ── Assign Pallet ─────────────────────────────
  Future<void> _assignPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      return;
    }

    if (_selectedLineIds.isEmpty) {
      showErrorDialog(context, message: 'กรุณาเลือก Part อย่างน้อย 1 รายการ');
      return;
    }

    final selectedLines = widget.scannedLines
        .where((l) => _selectedLineIds.contains(l.lineId))
        .toList();

    final confirm = await showConfirmDialog(
      context,
      title: 'ผูกสินค้ากับ Pallet',
      message:
          'ผูก ${selectedLines.length} รายการ\n'
          'กับ Pallet: $palletId ($_palletType)',
      confirmLabel: 'ยืนยัน',
    );
    if (!confirm) return;

    setState(() => _loading = true);

    // ถ้า offline → บันทึกลง queue
    if (!_isOnline) {
      await OfflineService().addToQueue(
        action: 'assign-pallet',
        data: {
          'sessionId': widget.session.sessionId,
          'palletId': palletId,
          'palletType': _palletType,
          'operatorId': widget.userId,
          'lineIds': _selectedLineIds.toList(),
        },
      );

      setState(() => _loading = false);

      if (!mounted) return;

      showWarningSnackbar(
        context,
        'บันทึกแบบ offline จะ sync เมื่อ WiFi กลับมา',
      );

      widget.onAssigned(_selectedLineIds.toList());

      if (mounted) Navigator.pop(context);
      return;
    }

    // online → ยิง API
    final result = await _api.assignPallet(
      sessionId: widget.session.sessionId,
      palletId: palletId,
      palletType: _palletType,
      operatorId: widget.userId,
      lineIds: _selectedLineIds.toList(),
    );

    setState(() => _loading = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    showSuccessSnackbar(context, '✅ Pallet $palletId ($_palletType) ผูกสำเร็จ');

    // แจ้ง scan_part_screen ว่า lines ไหนผูกแล้ว
    widget.onAssigned(_selectedLineIds.toList());

    // ตรวจว่าครบทุก Part ใน PO หรือยัง
    final remaining = widget.scannedLines
        .where((l) => !_selectedLineIds.contains(l.lineId))
        .toList();

    if (!mounted) return;

    if (remaining.isEmpty) {
      // ครบ → ถาม close session
      await _tryCloseSession();
    } else {
      // ยังมีเหลือ → กลับไปสแกน Part ต่อ
      Navigator.pop(context);
    }
  }

  // ── ปิด Session ───────────────────────────────
  Future<void> _tryCloseSession() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'ปิด Session',
      message: 'ผูก Part ครบทุกรายการแล้ว\nต้องการปิด session ไหม?',
      confirmLabel: 'ปิด Session',
    );

    if (!confirm) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _loading = true);

    final result = await _api.closeReceivingSession(widget.session.sessionId);

    setState(() => _loading = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    final poStatus = result.data!['poStatus'] as String;
    final message = result.data!['message'] as String;

    if (!mounted) return;

    // แสดงผลลัพธ์
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              poStatus == 'RECEIVED' ? Icons.check_circle : Icons.warning_amber,
              color: poStatus == 'RECEIVED'
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
            const SizedBox(width: 8),
            Text(
              poStatus == 'RECEIVED' ? 'รับสินค้าครบแล้ว' : 'รับสินค้าบางส่วน',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            InfoRow(label: 'PO', value: widget.po.poId),
            InfoRow(label: 'Status', value: poStatus),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // กลับไปหน้า scan PO
              Navigator.popUntil(
                context,
                (route) => route.isFirst || route.settings.name == '/',
              );
            },
            child: const Text('เสร็จสิ้น'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'สแกน Pallet', userName: widget.fullName),
      body: Column(
        children: [
          if (!_isOnline) const OfflineBanner(pendingCount: 0),

          Expanded(
            child: LoadingOverlay(
              loading: _loading,
              message: 'กำลังผูก Pallet...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Step Indicator ──────────
                    _buildStepIndicator(),
                    const SizedBox(height: 16),

                    // ── Pallet Input ────────────
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
                            onSubmit: () {},
                          ),
                          const SizedBox(height: 16),

                          // Pallet Type
                          const Text(
                            'ประเภท Pallet',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _TypeButton(
                                  label: 'FG',
                                  desc: 'พร้อมใช้ได้เลย',
                                  color: AppTheme.success,
                                  selected: _palletType == 'FG',
                                  onTap: () =>
                                      setState(() => _palletType = 'FG'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TypeButton(
                                  label: 'PW',
                                  desc: 'ต้องติดสติ๊กเกอร์ก่อน',
                                  color: Colors.orange,
                                  selected: _palletType == 'PW',
                                  onTap: () =>
                                      setState(() => _palletType = 'PW'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── เลือก Part ──────────────
                    _buildSelectParts(),
                    const SizedBox(height: 16),

                    // ── Confirm ─────────────────
                    PrimaryButton(
                      label:
                          'ผูก Pallet'
                          ' (${_selectedLineIds.length} รายการ)',
                      icon: Icons.link,
                      onPressed: _assignPallet,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Select Parts ─────────────────────────────
  Widget _buildSelectParts() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'เลือก Part ที่จะผูก',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedLineIds.length == widget.scannedLines.length) {
                      _selectedLineIds.clear();
                    } else {
                      _selectedLineIds.addAll(
                        widget.scannedLines.map((l) => l.lineId),
                      );
                    }
                  });
                },
                child: Text(
                  _selectedLineIds.length == widget.scannedLines.length
                      ? 'ยกเลิกทั้งหมด'
                      : 'เลือกทั้งหมด',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.scannedLines.map((line) {
            final selected = _selectedLineIds.contains(line.lineId);
            return GestureDetector(
              onTap: () {
                setState(() {
                  selected
                      ? _selectedLineIds.remove(line.lineId)
                      : _selectedLineIds.add(line.lineId);
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.05)
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.4)
                        : Colors.grey.shade200,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: selected ? AppTheme.primary : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.partId,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            line.itemDesc,
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
                          '${line.qtyReceived} ชิ้น',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        StatusBadge(line.condition),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepDot(number: 1, label: 'สแกน PO', done: true),
        _StepLine(),
        _StepDot(number: 2, label: 'สแกน Part', done: true),
        _StepLine(),
        _StepDot(number: 3, label: 'สแกน Pallet', active: true),
      ],
    );
  }
}

// ── Type Button ───────────────────────────────
class _TypeButton extends StatelessWidget {
  final String label;
  final String desc;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.desc,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppTheme.background,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.grey,
              ),
            ),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11,
                color: selected ? color : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Widgets ──────────────────────────────
class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool done;

  const _StepDot({
    required this.number,
    required this.label,
    this.active = false,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppTheme.success
        : active
        ? AppTheme.primary
        : Colors.grey.shade300;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
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
            color: active || done ? AppTheme.primary : Colors.grey,
            fontWeight: active || done ? FontWeight.w600 : FontWeight.normal,
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
