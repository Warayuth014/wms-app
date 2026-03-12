// lib/screens/flow2/load_basket_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
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

  List<ConfirmedUnloadItem> _allItems = [];
  List<ConfirmedUnloadItem> _filtered = [];
  List<LoadedBasketItem> _loadedItems = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      ApiService().getConfirmedUnloadItems(),
      ApiService().getLoadedBasketItems(),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);

    final confirmed = results[0] as ApiResult<List<ConfirmedUnloadItem>>;
    final loaded = results[1] as ApiResult<List<LoadedBasketItem>>;

    if (!confirmed.success) {
      showErrorDialog(context, message: confirmed.error ?? 'โหลดข้อมูลไม่ได้');
      return;
    }

    setState(() {
      _allItems = confirmed.data ?? [];
      _filtered = _allItems;
      _loadedItems = loaded.data ?? [];
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
      body: Column(
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
                fillColor: AppTheme.surface,
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
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                  ),
                ),
                if (_allItems.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    'ทั้งหมด ${_allItems.length} รายการรอ load',
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
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── รอคืนตะกร้า ──────────
                        if (_loadedItems.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_basket,
                                  color: AppTheme.warning,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'รอคืนตะกร้า (${_loadedItems.length})',
                                  style: const TextStyle(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._loadedItems.map(_buildLoadedItemCard),
                          const SizedBox(height: 16),
                        ],

                        // ── รอ Load ───────────────
                        if (_filtered.isEmpty)
                          _buildEmpty()
                        else ...[
                          if (_loadedItems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.category,
                                      color: AppTheme.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'รอ Load (${_filtered.length})',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ..._filtered.asMap().entries.map(
                            (e) => Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    e.key < _filtered.length - 1 ? 8.0 : 0.0,
                              ),
                              child: _buildItemCard(e.value),
                            ),
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
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 15),
          ),
          if (_allItems.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'กรุณา Unload สินค้าก่อน',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(ConfirmedUnloadItem item) {
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
        // refresh หลังกลับมา
        _loadItems();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Part Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.category,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Info
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
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        size: 12,
                        color: AppTheme.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.palletId,
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.numbers,
                        size: 12,
                        color: AppTheme.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.qtyUnloaded} ชิ้น',
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

            // Arrow
            const Icon(Icons.chevron_right, color: AppTheme.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedItemCard(LoadedBasketItem loaded) {
    final fakeItem = ConfirmedUnloadItem(
      lineId: loaded.lineId,
      partId: loaded.partId,
      palletId: loaded.palletId,
      itemDesc: loaded.itemDesc,
      owner: loaded.owner,
      qtyUnloaded: loaded.qtyLoaded,
      lotNumber: loaded.lotNumber,
    );

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoadBasketDetailScreen(
              userId: widget.userId,
              fullName: widget.fullName,
              item: fakeItem,
              preloaded: loaded,
            ),
          ),
        );
        _loadItems();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shopping_basket,
                color: AppTheme.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loaded.partId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    loaded.itemDesc,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_basket,
                        size: 12,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loaded.basketLabel,
                        style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (loaded.basketDestination != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: AppTheme.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          loaded.basketDestination!,
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.arrow_upward, color: AppTheme.warning, size: 20),
                Text(
                  'คืนตะกร้า',
                  style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
