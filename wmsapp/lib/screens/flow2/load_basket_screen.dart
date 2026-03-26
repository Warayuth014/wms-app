// lib/screens/flow2/load_basket_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import '../../widgets/part_thumbnail.dart';
import 'load_basket_detail_screen.dart';

class LoadBasketScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const LoadBasketScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<LoadBasketScreen> createState() => _LoadBasketScreenState();
}

class _LoadBasketScreenState extends State<LoadBasketScreen> {
  final _filterController = TextEditingController();

  List<GroupedUnloadItem> _allItems = [];
  List<GroupedUnloadItem> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);

    final result = await ApiService().getConfirmedUnloadItems();

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่ได้');
      return;
    }

    setState(() {
      _allItems = result.data ?? [];
      _filter(_filterController.text);
    });
  }

  void _filter(String query) {
    final q = query.trim().toUpperCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allItems
          : _allItems
                .where(
                  (i) =>
                      i.partId.toUpperCase().contains(q) ||
                      i.itemDesc.toUpperCase().contains(q),
                )
                .toList();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Load Basket',
        userName: widget.fullName,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Search Bar ───────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _filterController,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'ค้นหา Part ID หรือชื่อสินค้า...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filterController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _filterController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ── Count ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'พบ ${_filtered.length} รายการ',
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 13,
                    ),
                  ),
                  if (_allItems.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      'รวม ${_allItems.fold<int>(0, (s, i) => s + i.totalQty)} ชิ้นรอ load',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── List ─────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildItemCard(_filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _allItems.isEmpty
                ? 'ยังไม่มีสินค้ารอ Load Basket'
                : 'ไม่พบสินค้าที่ค้นหา',
            style: TextStyle(color: AppTheme.textGrey(context), fontSize: 15),
          ),
          if (_allItems.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'กรุณา Unload สินค้าก่อน',
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(GroupedUnloadItem item) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoadBasketDetailScreen(
              userId: widget.userId,
              fullName: widget.fullName,
              item: item,
            ),
          ),
        );
        _loadItems();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            PartThumbnail(imageUrl: item.imageUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.partId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    item.itemDesc,
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 13,
                    ),
                  ),
                  if (item.lotNumber != null && item.lotNumber!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 14,
                          color: AppTheme.textGrey(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Batch No : ${item.lotNumber}',
                            style: TextStyle(
                              color: AppTheme.textGrey(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${item.owner} / ${item.brand}',
                    style: TextStyle(
                      color: AppTheme.textGrey(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.totalQty} ชิ้น',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppTheme.textGrey(context)),
          ],
        ),
      ),
    );
  }
}
