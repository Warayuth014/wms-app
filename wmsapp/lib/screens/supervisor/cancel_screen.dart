// lib/screens/supervisor/cancel_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

class CancelScreen extends StatefulWidget {
  final String userId;

  const CancelScreen({super.key, required this.userId});

  @override
  State<CancelScreen> createState() => _CancelScreenState();
}

class _CancelScreenState extends State<CancelScreen> {
  final _api = ApiService();

  List<CancelLog> _pendingLogs = [];
  bool _loading = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  // ── โหลด Pending Cancels ──────────────────────
  Future<void> _loadPending() async {
    setState(() => _loading = true);

    final result = await _api.getPendingCancels();
    setState(() => _loading = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() => _pendingLogs = result.data ?? []);
  }

  // ── Approve ───────────────────────────────────
  Future<void> _approve(CancelLog log) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'อนุมัติการยกเลิก',
      message:
          'อนุมัติยกเลิก ${log.refType} #${log.refId}?\n\n'
          'เหตุผล: ${log.reason}\n'
          'ผู้ขอ: ${log.requestBy}',
      confirmLabel: 'อนุมัติ',
    );
    if (!confirm) return;

    setState(() => _processing = true);

    final result = await _api.approveCancel(
      cancelId: log.cancelId,
      approvedBy: widget.userId,
    );

    setState(() => _processing = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    showSuccessSnackbar(
      context,
      '✅ อนุมัติยกเลิก ${log.refType} #${log.refId} แล้ว',
    );

    _loadPending();
  }

  // ── Reject ────────────────────────────────────
  Future<void> _reject(CancelLog log) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'ปฏิเสธการยกเลิก',
      message:
          'ปฏิเสธคำขอยกเลิก ${log.refType} #${log.refId}?\n\n'
          'เหตุผล: ${log.reason}\n'
          'ผู้ขอ: ${log.requestBy}',
      confirmLabel: 'ปฏิเสธ',
      isDanger: true,
    );
    if (!confirm) return;

    setState(() => _processing = true);

    final result = await _api.rejectCancel(
      cancelId: log.cancelId,
      supervisorId: widget.userId,
    );

    setState(() => _processing = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    showWarningSnackbar(
      context,
      'ปฏิเสธคำขอยกเลิก ${log.refType} #${log.refId}',
    );

    _loadPending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Cancel Approval',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'รีเฟรช',
            onPressed: _loadPending,
          ),
        ],
      ),
      body: LoadingOverlay(
        loading: _processing,
        message: 'กำลังดำเนินการ...',
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pendingLogs.isEmpty
            ? _buildEmptyState()
            : _buildList(),
      ),
    );
  }

  // ── Empty State ───────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppTheme.success.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'ไม่มีคำขอที่รอดำเนินการ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ทุกรายการได้รับการดำเนินการแล้ว',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              onPressed: _loadPending,
              icon: const Icon(Icons.refresh),
              label: const Text('รีเฟรช'),
            ),
          ),
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────
  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary ──────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions, color: AppTheme.warning),
                const SizedBox(width: 12),
                Text(
                  'รอดำเนินการ ${_pendingLogs.length} รายการ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // ── Cancel Log Cards ──────────────────
          ..._pendingLogs.map((log) => _buildLogCard(log)),
        ],
      ),
    );
  }

  // ── Log Card ──────────────────────────────────
  Widget _buildLogCard(CancelLog log) {
    final refColor = switch (log.refType) {
      'ReceiptLine' => AppTheme.primary,
      'UnloadLine' => AppTheme.secondary,
      'BasketLine' => AppTheme.success,
      _ => Colors.grey,
    };

    final refIcon = switch (log.refType) {
      'ReceiptLine' => Icons.move_to_inbox,
      'UnloadLine' => Icons.output,
      'BasketLine' => Icons.shopping_basket,
      _ => Icons.help_outline,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: refColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(refIcon, color: refColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  log.refType,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: refColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: refColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${log.refId}',
                    style: TextStyle(
                      color: refColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                StatusBadge(log.status),
              ],
            ),
          ),

          // ── Body ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // เหตุผล
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 16, color: AppTheme.textGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.reason,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ผู้ขอ
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.textGrey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ขอโดย: ${log.requestBy}',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Action Buttons ────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(log),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('ปฏิเสธ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approve(log),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('อนุมัติ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
