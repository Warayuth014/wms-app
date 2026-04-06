// lib/screens/receiving/pending_pallet/pending_pallet_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import 'widgets/pending_pallet_empty_state.dart';
import 'widgets/pending_pallet_po_group.dart';

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
    final result = await _api.getPendingPalletLines();
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _lines = result.data!;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);
    showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่ได้');
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
              const Icon(Icons.pallet, color: AppTheme.primary),
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
                TextField(
                  controller: palletCtrl,
                  focusNode: palletFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Pallet ID',
                    hintText: 'สแกนหรือพิมพ์ Pallet ID',
                    prefixIcon: Icon(MdiIcons.barcodeScan),
                  ),
                  onSubmitted: assigning
                      ? null
                      : (_) => _doAssign(
                            ctx,
                            line,
                            palletCtrl,
                            () => setDlg(() => assigning = true),
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

    final result = await _api.assignPallet(
      sessionId: line.sessionId,
      palletId: palletId,
      palletType: line.condition,
      operatorId: widget.userId,
      lineIds: [line.lineId],
    );

    if (!mounted) return;
    if (!dlgCtx.mounted) return;

    Navigator.pop(dlgCtx);

    if (!mounted) return;

    if (result.success) {
      showSuccessSnackbar(
        context,
        'ผูก Pallet $palletId สำเร็จ - ${line.partId}',
      );
      _load();
      return;
    }

    showErrorDialog(
      context,
      title: 'ผูก Pallet ไม่สำเร็จ',
      message: result.error ?? 'เกิดข้อผิดพลาด',
    );
  }

  Map<String, List<PendingPalletLine>> _groupedLines() {
    final grouped = <String, List<PendingPalletLine>>{};
    for (final line in _lines) {
      grouped.putIfAbsent(line.poId, () => []).add(line);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedLines();

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
            ? const PendingPalletEmptyState()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final poId = grouped.keys.elementAt(index);
                    final items = grouped[poId]!;
                    return PendingPalletPoGroup(
                      poId: poId,
                      items: items,
                      onSelectLine: _openAssignDialog,
                    );
                  },
                ),
              ),
      ),
    );
  }
}
