// lib/screens/test/test_sorting_screen.dart
//
// Hidden dev harness: เลือก Pack ที่ Status=DONE → สร้าง Sorting batch
// → backend จะ assign ไป Station ว่าง (หรือ queue ถ้าเต็ม)

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

class TestSortingScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const TestSortingScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<TestSortingScreen> createState() => _TestSortingScreenState();
}

class _TestSortingScreenState extends State<TestSortingScreen> {
  final _api = ApiService();
  bool _loading = false;

  List<AvailablePackForSorting> _packs = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getAvailablePacksForSorting();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'โหลดข้อมูลไม่ได้');
      return;
    }
    setState(() {
      _packs = res.data!;
      _selected.clear();
    });
  }

  Future<void> _createBatch() async {
    if (_selected.isEmpty) {
      showErrorDialog(context, message: 'กรุณาเลือก Pack อย่างน้อย 1 รายการ');
      return;
    }

    final confirm = await showConfirmDialog(
      context,
      title: 'สร้าง Sorting Batch',
      message:
          'รวม ${_selected.length} packs เป็น 1 batch\n'
          'ระบบจะ auto-assign ไป Station ว่าง\n'
          'แต่ละ pack จะไหลเข้า station ห่างกัน 2 วินาที',
      confirmLabel: 'สร้าง Batch',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);
    final res = await _api.createSortingBatch(
      operatorId: widget.userId,
      packingIds: _selected.toList(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'สร้างไม่สำเร็จ');
      return;
    }

    final r = res.data!;
    showSuccessSnackbar(
      context,
      r.isQueued
          ? 'Queued (Station เต็มหมด — รอคิว)'
          : 'Batch ${r.batchSize} packs → SP-${r.stationId.toString().padLeft(2, '0')}',
    );
    await _load();
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _packs.length) {
        _selected.clear();
      } else {
        _selected.addAll(_packs.map((p) => p.packingId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Test Sorting Batch',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังโหลด...',
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Icon(MdiIcons.flaskOutline,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'เลือก Pack ที่ DONE → group เป็น batch (${_selected.length}/${_packs.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _packs.isEmpty ? null : _toggleAll,
                      child: Text(
                        _selected.length == _packs.length
                            ? 'Clear All'
                            : 'Select All',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _packs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(MdiIcons.packageVariantClosedRemove,
                                  color: Colors.grey[400], size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'ไม่มี Pack ที่ Status=DONE\nหรือถูก sort ไปหมดแล้ว',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _packs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _buildPackTile(_packs[i]),
                      ),
              ),
              if (_selected.isNotEmpty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PrimaryButton(
                      label: 'สร้าง Batch (${_selected.length} packs)',
                      icon: Icons.pallet,
                      onPressed: _createBatch,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackTile(AvailablePackForSorting p) {
    final selected = _selected.contains(p.packingId);
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _selected.remove(p.packingId);
          } else {
            _selected.add(p.packingId);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.border(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? AppTheme.primary : Colors.grey[500],
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.packingId,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      _chip(p.owner, AppTheme.secondary),
                      Text('${p.itemCount} ชิ้น',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text('${p.orderCount} order',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  if (p.customerOrderId != null)
                    Text(p.customerOrderId!,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}
