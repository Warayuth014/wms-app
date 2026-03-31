// lib/screens/flow2/replenish_work_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

// ====================================================
// ReplenishWorkScreen — Tote-first Replenishment Workflow
// Flow: Scan Tote → Scan Pallet → Open Session → Confirm Lines → Complete
// ====================================================
class ReplenishWorkScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final ReplenishOrderResponse order;

  const ReplenishWorkScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.order,
  });

  @override
  State<ReplenishWorkScreen> createState() => _ReplenishWorkScreenState();
}

class _ReplenishWorkScreenState extends State<ReplenishWorkScreen> {
  final _api = ApiService();

  // Step 0 = scan tote, 1 = scan pallet, 2 = working session
  int _step = 0;

  final _toteCtrl = TextEditingController();
  final _palletCtrl = TextEditingController();

  ToteScanResponse? _tote;
  ReplenishSessionResponse? _session;

  bool _loading = false;

  @override
  void dispose() {
    _toteCtrl.dispose();
    _palletCtrl.dispose();
    super.dispose();
  }

  // ── Step 0: Scan Tote ────────────────────────────
  Future<void> _scanTote() async {
    final id = _toteCtrl.text.trim().toUpperCase();
    if (id.isEmpty) return;
    setState(() => _loading = true);
    final r = await _api.scanTote(id);
    setState(() => _loading = false);
    if (!mounted) return;
    if (!r.success) { showErrorDialog(context, message: r.error!); return; }
    setState(() {
      _tote = r.data!;
      _step = 1;
    });
  }

  // ── Step 1: Scan Pallet & Open Session ──────────
  Future<void> _openSession() async {
    final palletId = _palletCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;
    setState(() => _loading = true);
    final r = await _api.openReplenishSession(
      orderId: widget.order.orderId,
      toteId: _tote!.toteId,
      palletId: palletId,
      operatorId: widget.userId,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (!r.success) { showErrorDialog(context, message: r.error!); return; }
    setState(() {
      _session = r.data!;
      _step = 2;
    });
  }

  // ── Step 2: Confirm line qty ────────────────────
  Future<void> _confirmLine(ReplenishSessionLineDto line) async {
    // แสดง dialog รับ qty
    final qty = await _showQtyDialog(line);
    if (qty == null) return;

    setState(() => _loading = true);
    final r = await _api.confirmReplenishLine(
      sessionId: _session!.sessionId,
      sessionLineId: line.lineId,
      qtyFilled: qty,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (!r.success) { showErrorDialog(context, message: r.error!); return; }

    // อัปเดต local state ทันที
    setState(() {
      final target = _session!.lines.firstWhere((l) => l.lineId == line.lineId);
      target.qtyFilled = qty;
      target.sessionLineStatus = 'CONFIRMED';
    });
  }

  // ── Step 2: Complete Session ────────────────────
  Future<void> _completeSession() async {
    final allConfirmed =
        _session!.lines.every((l) => l.sessionLineStatus == 'CONFIRMED');
    if (!allConfirmed) {
      showErrorDialog(context, message: 'ยืนยันทุกรายการก่อน Complete');
      return;
    }

    setState(() => _loading = true);
    final r = await _api.completeReplenishSession(_session!.sessionId);
    setState(() => _loading = false);
    if (!mounted) return;
    if (!r.success) { showErrorDialog(context, message: r.error!); return; }

    final orderStatus = r.data!['orderStatus'] as String? ?? '';
    final msg = r.data!['message'] as String? ?? 'เสร็จสิ้น';
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 56),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            if (orderStatus == 'COMPLETED') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Order ครบทุกรายการแล้ว ✓',
                  style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to order list
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showQtyDialog(ReplenishSessionLineDto line) async {
    final ctrl = TextEditingController(text: line.qtyRequired.toString());
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(line.itemDesc, style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ต้องการ: ${line.qtyRequired} ชิ้น',
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'จำนวนที่เติม',
                border: OutlineInputBorder(),
                suffixText: 'ชิ้น',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 0) Navigator.pop(context, v);
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Order #${widget.order.orderId} — เติมสินค้า',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังโหลด...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress stepper
                _buildStepper(),
                const SizedBox(height: 20),

                // Step content
                if (_step == 0) _buildScanTote(),
                if (_step == 1) _buildScanPallet(),
                if (_step == 2) _buildSession(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['Scan Tote', 'Scan Pallet', 'เติมสินค้า'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: i ~/ 2 < _step
                  ? AppTheme.primary
                  : Colors.grey.shade300,
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < _step;
        final active = idx == _step;
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppTheme.success
                    : active
                        ? AppTheme.primary
                        : Colors.grey.shade200,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx],
              style: TextStyle(
                fontSize: 10,
                color: active ? AppTheme.primary : Colors.grey,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Step 0 ──────────────────────────────────────
  Widget _buildScanTote() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Scan Tote ID', icon: Icons.qr_code_scanner),
          const SizedBox(height: 12),
          TextField(
            controller: _toteCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Tote ID',
              prefixIcon: Icon(Icons.inventory_2_outlined),
              border: OutlineInputBorder(),
              hintText: 'เช่น TOTE-001',
            ),
            onSubmitted: (_) => _scanTote(),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'ยืนยัน Tote',
            icon: Icons.arrow_forward,
            onPressed: _scanTote,
          ),
        ],
      ),
    );
  }

  // ── Step 1 ──────────────────────────────────────
  Widget _buildScanPallet() {
    return Column(
      children: [
        // Tote info summary
        WmsCard(
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tote!.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'ID: ${_tote!.toteId} | ${_tote!.status}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() { _step = 0; _tote = null; }),
                child: const Text('เปลี่ยน'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WmsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Scan Pallet (REPLENISH)', icon: Icons.qr_code_scanner),
              const SizedBox(height: 12),
              TextField(
                controller: _palletCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Pallet ID',
                  prefixIcon: Icon(Icons.view_in_ar_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'เช่น PLT-0001',
                ),
                onSubmitted: (_) => _openSession(),
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
    );
  }

  // ── Step 2 ──────────────────────────────────────
  Widget _buildSession() {
    if (_session == null) return const SizedBox();
    final confirmedCount = _session!.lines.where((l) => l.sessionLineStatus == 'CONFIRMED').length;
    final total = _session!.lines.length;
    final allDone = confirmedCount == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session info
        WmsCard(
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tote: ${_session!.toteId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Pallet: ${_session!.palletId}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textGrey(context))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allDone
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confirmedCount/$total',
                  style: TextStyle(
                    color: allDone ? AppTheme.success : AppTheme.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Lines
        for (final line in _session!.lines) ...[
          _buildSessionLine(line),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),

        // Complete button
        PrimaryButton(
          label: allDone ? 'Complete Session' : 'ยืนยันทุกรายการก่อน Complete',
          icon: allDone ? Icons.check_circle : Icons.pending,
          onPressed: allDone ? _completeSession : () {},
        ),
      ],
    );
  }

  Widget _buildSessionLine(ReplenishSessionLineDto line) {
    final done = line.sessionLineStatus == 'CONFIRMED';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done
            ? AppTheme.success.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done
              ? AppTheme.success.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: done ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppTheme.success : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.itemDesc,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${line.partId} | ต้องการ: ${line.qtyRequired}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
                ),
                if (done)
                  Text(
                    'เติมแล้ว: ${line.qtyFilled} ชิ้น',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (!done)
            FilledButton.icon(
              onPressed: () => _confirmLine(line),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('เติม', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
