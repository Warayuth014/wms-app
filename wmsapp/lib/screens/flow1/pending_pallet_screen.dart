// lib/screens/flow1/pending_pallet_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import '../../widgets/part_thumbnail.dart';

class PendingPalletScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PendingPalletScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PendingPalletScreen> createState() => _PendingPalletScreenState();
}

class _PendingPalletScreenState extends State<PendingPalletScreen> {
  final _api = ApiService();
  List<PendingPalletLine> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _api.getPendingPalletLines();
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _lines = r.data!;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      showErrorDialog(context, message: r.error ?? 'โหลดข้อมูลไม่ได้');
    }
  }

  void _openAssignDialog(PendingPalletLine line) {
    final palletCtrl = TextEditingController();
    final palletFocus = FocusNode();
    bool assigning = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.pallet, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ผูก Pallet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ข้อมูล Part ──────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.partId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line.itemDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusBadge(line.condition),
                          const SizedBox(width: 8),
                          Text(
                            'Qty: ${line.qtyReceived}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PO: ${line.poId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textGrey(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── สแกน Pallet ──────────────────────
                TextField(
                  controller: palletCtrl,
                  focusNode: palletFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Pallet ID',
                    hintText: 'สแกนหรือพิมพ์ Pallet ID',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                  onSubmitted: assigning
                      ? null
                      : (_) => _doAssign(
                          ctx,
                          setDlg,
                          line,
                          palletCtrl,
                          () => assigning = true,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ถ้า Pallet มีสินค้าอยู่แล้วต้องเป็น Type เดียวกัน (${line.condition})',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: assigning ? null : () => Navigator.pop(ctx),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: AppTheme.textGrey(context)),
              ),
            ),
            ElevatedButton(
              onPressed: assigning
                  ? null
                  : () => _doAssign(
                      ctx,
                      setDlg,
                      line,
                      palletCtrl,
                      () => setDlg(() => assigning = true),
                    ),
              child: assigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doAssign(
    BuildContext dlgCtx,
    StateSetter setDlg,
    PendingPalletLine line,
    TextEditingController palletCtrl,
    VoidCallback markLoading,
  ) async {
    final palletId = palletCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(dlgCtx, message: 'กรุณาใส่ Pallet ID');
      return;
    }

    markLoading();

    final r = await _api.assignPallet(
      sessionId: line.sessionId,
      palletId: palletId,
      palletType: line.condition, // FG หรือ PW
      operatorId: widget.userId,
      lineIds: [line.lineId],
    );

    if (!mounted) return;

    // ปิด dialog ก่อนเสมอ
    // ignore: use_build_context_synchronously
    Navigator.pop(dlgCtx);

    if (!mounted) return;

    if (r.success) {
      showSuccessSnackbar(
        context,
        'ผูก Pallet $palletId สำเร็จ — ${line.partId}',
      );
      _load(); // รีเฟรชรายการ
    } else {
      // 400 หรือ error อื่น → popup แสดง message
      showErrorDialog(
        context,
        title: 'ผูก Pallet ไม่สำเร็จ',
        message: r.error ?? 'เกิดข้อผิดพลาด',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'ค้างการผูก Pallet',
        userName: widget.fullName,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _lines.isEmpty
            ? _buildEmpty()
            : _buildList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: AppTheme.success),
          const SizedBox(height: 16),
          Text(
            'ไม่มีรายการค้างการผูก Pallet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ทุกรายการผูก Pallet เรียบร้อยแล้ว',
            style: TextStyle(fontSize: 14, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // จัดกลุ่มตาม PO
    final grouped = <String, List<PendingPalletLine>>{};
    for (final l in _lines) {
      grouped.putIfAbsent(l.poId, () => []).add(l);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (ctx, i) {
          final poId = grouped.keys.elementAt(i);
          final items = grouped[poId]!;
          return _buildPoGroup(poId, items);
        },
      ),
    );
  }

  Widget _buildPoGroup(String poId, List<PendingPalletLine> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header PO ────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'PO: $poId',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  border: Border.all(color: AppTheme.warning),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} รายการ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── รายการใต้ PO ─────────────────────────
        ...items.map((line) => _buildLineCard(line)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLineCard(PendingPalletLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAssignDialog(line),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Product thumbnail ───────────────
              PartThumbnail(imageUrl: line.imageUrl, size: 44),
              const SizedBox(width: 12),
              // ── ข้อมูล ────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.partId,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.itemDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (line.lotNumber != null) ...[
                          Icon(
                            Icons.label_outline,
                            size: 12,
                            color: AppTheme.textGrey(context),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Batch No.: ${line.lotNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textGrey(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        StatusBadge(line.condition),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${line.owner} / ${line.brand}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Qty: ${line.qtyReceived}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── ปุ่มผูก ───────────────────────
              Column(
                children: [
                  Icon(Icons.link, color: AppTheme.primary, size: 22),
                  const SizedBox(height: 2),
                  const Text(
                    'ผูก',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
