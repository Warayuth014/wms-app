// lib/screens/picking/picking_session_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import 'pick_items_screen.dart';

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
  final _packPalletController = TextEditingController();
  final _packPalletFocus = FocusNode();
  final _api = ApiService();

  bool _loading = false;
  PickingSession? _session;
  List<PickingLineItem> _pickedLines = [];

  // ── Scan Pack Pallet & Open Session ────────
  Future<void> _openSession() async {
    final packPalletId = _packPalletController.text.trim().toUpperCase();
    if (packPalletId.isEmpty) return;

    setState(() => _loading = true);

    final result = await _api.openPickingSession(
      packPalletId: packPalletId,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่สามารถเปิด Session ได้');
      _packPalletController.clear();
      _packPalletFocus.requestFocus();
      return;
    }

    setState(() {
      _session = result.data;
      _pickedLines = result.data!.pickedLines;
    });
  }

  // ── ไปหน้า Pick Items ─────────────────────
  void _goToPickItems() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickItemsScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          sessionId: _session!.sessionId,
          packPalletId: _session!.packPalletId,
        ),
      ),
    ).then((_) => _refreshSession());
  }

  // ── Refresh session data ───────────────────
  Future<void> _refreshSession() async {
    if (_session == null) return;

    final session = await _api.getActivePickingSession(_session!.packPalletId);
    if (!mounted) return;

    if (session != null) {
      setState(() {
        _session = session;
        _pickedLines = session.pickedLines;
      });
    } else {
      // Session ถูกปิดไปแล้ว
      setState(() {
        _session = null;
        _pickedLines = [];
      });
    }
  }

  // ── Complete Session ───────────────────────
  Future<void> _completeSession() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'ปิด Picking Session',
      message:
          'Pack Pallet: ${_session!.packPalletId}\n'
          'รวม ${_pickedLines.length} รายการ\n\n'
          'ยืนยันว่า Pack Pallet ครบแล้ว?',
      confirmLabel: 'ยืนยัน ปิด Session',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await _api.completePickingSession(_session!.sessionId);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่สามารถปิด Session ได้');
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            SizedBox(width: 8),
            Text('Picking เสร็จสิ้น'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: 'Pack Pallet', value: result.data!.packPalletId),
            InfoRow(
              label: 'รวม Pick',
              value: '${result.data!.totalItemsPicked} ชิ้น',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('กลับหน้าหลัก'),
          ),
        ],
      ),
    );
  }

  // ── Reset ──────────────────────────────────
  void _reset() {
    setState(() {
      _session = null;
      _pickedLines = [];
      _packPalletController.clear();
    });
    _packPalletFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Picking', userName: widget.fullName),
      body: LoadingOverlay(
        loading: _loading,
        message: 'กำลังดำเนินการ...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Step Indicator ──────────
              _buildStepIndicator(),
              const SizedBox(height: 20),

              // ── No Session: Scan Pack Pallet ──
              if (_session == null) ...[
                WmsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            'Scan Pack Pallet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'สแกน Pallet ที่จะเอาไป Pack (ปลายทาง)',
                        style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                      ),
                      const SizedBox(height: 12),
                      ScanTextField(
                        label: 'Pack Pallet ID',
                        hint: 'Scan Pack Pallet ID',
                        controller: _packPalletController,
                        onSubmit: _openSession,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'เปิด Session',
                        icon: Icons.play_arrow,
                        onPressed: _openSession,
                      ),
                    ],
                  ),
                ),
              ],

              // ── Session Active ─────────────────
              if (_session != null) ...[
                // Pack Pallet Info
                WmsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Pack Pallet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(_session!.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Pallet ID',
                        value: _session!.packPalletId,
                        bold: true,
                      ),
                      InfoRow(
                        label: 'Session',
                        value: '#${_session!.sessionId}',
                      ),
                      InfoRow(
                        label: 'รายการ Pick',
                        value: '${_pickedLines.length} รายการ',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Scan Pick Pallet',
                        icon: Icons.qr_code_scanner,
                        onPressed: _goToPickItems,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Picked Items List ────────────
                if (_pickedLines.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.checklist, color: AppTheme.success, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'รายการที่ Pick แล้ว (${_pickedLines.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._pickedLines.map((line) => _buildPickedLineCard(line)),
                ],

                const SizedBox(height: 16),

                // Complete / Reset
                Row(
                  children: [
                    Expanded(
                      child: DangerButton(
                        label: 'ยกเลิก',
                        icon: Icons.close,
                        onPressed: () async {
                          final confirm = await showConfirmDialog(
                            context,
                            title: 'ยกเลิก Session',
                            message: 'ต้องการยกเลิกและกลับหน้าหลัก?',
                            confirmLabel: 'ยกเลิก',
                            isDanger: true,
                          );
                          if (confirm) _reset();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Pack ครบ ปิด Session',
                        icon: Icons.check_circle,
                        onPressed: _pickedLines.isNotEmpty
                            ? _completeSession
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final step = _session == null ? 0 : 1;
    return Row(
      children: [
        _StepDot(number: 1, state: step == 0 ? 'active' : 'done'),
        Expanded(child: _StepLine(done: step > 0)),
        _StepDot(number: 2, state: step >= 1 ? 'active' : 'pending'),
      ],
    );
  }

  Widget _buildPickedLineCard(PickingLineItem line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.partId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${line.qtyPicked}',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            line.itemDesc,
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 2),
          Text(
            'จาก: ${line.pickPalletId}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
          if (line.lotNumber != null || line.expiredDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (line.lotNumber != null) ...[
                    const Icon(Icons.tag, size: 12, color: AppTheme.textGrey),
                    const SizedBox(width: 2),
                    Text(
                      line.lotNumber!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (line.expiredDate != null) ...[
                    const Icon(Icons.calendar_today,
                        size: 12, color: AppTheme.textGrey),
                    const SizedBox(width: 2),
                    Text(
                      line.expiredDate!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _packPalletController.dispose();
    _packPalletFocus.dispose();
    super.dispose();
  }
}

// ── Step Indicator Widgets ───────────────────
class _StepDot extends StatelessWidget {
  final int number;
  final String state; // pending | active | done

  const _StepDot({required this.number, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      'done' => AppTheme.success,
      'active' => AppTheme.primary,
      _ => AppTheme.border,
    };

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: state == 'pending' ? Colors.white : color,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: state == 'done'
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$number',
                style: TextStyle(
                  color: state == 'pending' ? AppTheme.textGrey : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;

  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: done ? AppTheme.success : AppTheme.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
