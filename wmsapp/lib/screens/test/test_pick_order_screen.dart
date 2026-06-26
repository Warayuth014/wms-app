// lib/screens/test/test_pick_order_screen.dart

import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../widgets/part_thumbnail.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TestPickOrderScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const TestPickOrderScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<TestPickOrderScreen> createState() => _TestPickOrderScreenState();
}

class _TestPickOrderScreenState extends State<TestPickOrderScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _lines = [];

  // lineId → selected
  final Set<int> _selected = {};
  // lineId → qty controller
  final Map<int, TextEditingController> _qtyCtrl = {};

  // Hidden dev shortcut — long-press title to reveal Quick Create
  bool _showQuickCreate = false;

  // Hidden return-pallet panel — long-press box icon to reveal
  bool _showReturnPallet = false;
  final _returnPalletCtrl = TextEditingController();
  final _returnPalletFocus = FocusNode();
  String _returnDest = 'ASRS';   // ASRS | ZONE_PACK

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrl.values) {
      c.dispose();
    }
    _returnPalletCtrl.dispose();
    _returnPalletFocus.dispose();
    super.dispose();
  }

  Widget _destChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.warning.withValues(alpha: 0.18)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.warning
                : AppTheme.warning.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? AppTheme.warning
                    : AppTheme.warning.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected
                    ? AppTheme.warning
                    : AppTheme.warning.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPallet() async {
    final palletId = _returnPalletCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      _returnPalletFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);
    // PICK → simulation endpoint (ส่ง pallet เปล่าไปรอ pick zone)
    // ASRS/ZONE_PACK → standard return-pallet endpoint
    final ok = _returnDest == 'PICK'
        ? (await _api.simulateSendPalletToPick(palletId: palletId))
        : (await _api.returnPallet(palletId: palletId, destination: _returnDest));

    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok.success) {
      showErrorDialog(context,
          message: ok.error ?? 'ส่ง $palletId → $_returnDest ไม่สำเร็จ');
      _returnPalletFocus.requestFocus();
      return;
    }

    showSuccessSnackbar(context, '📦 ส่ง $palletId → $_returnDest แล้ว');
    _returnPalletCtrl.clear();
    _returnPalletFocus.requestFocus();
  }

  Future<void> _loadLines() async {
    setState(() => _loading = true);
    final result = await _api.getAvailableLines();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่ได้');
      return;
    }

    setState(() {
      _lines = result.data!;
      _selected.clear();
      for (final c in _qtyCtrl.values) {
        c.dispose();
      }
      _qtyCtrl.clear();
      for (final line in _lines) {
        final lineId = line['lineId'] as int;
        final available = line['availableQty'] as int;
        _qtyCtrl[lineId] = TextEditingController(text: '$available');
      }
    });
  }

  Future<void> _createOrder() async {
    if (_selected.isEmpty) {
      showErrorDialog(context, message: 'กรุณาเลือกสินค้าอย่างน้อย 1 รายการ');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final lineId in _selected) {
      final line = _lines.firstWhere((l) => l['lineId'] == lineId);
      final qty = int.tryParse(_qtyCtrl[lineId]?.text.trim() ?? '') ?? 0;
      if (qty <= 0) {
        showErrorDialog(
          context,
          message: 'จำนวนต้องมากกว่า 0 (${line['partId']})',
        );
        return;
      }
      final available = line['availableQty'] as int;
      if (qty > available) {
        showErrorDialog(
          context,
          message: '${line['partId']} มีแค่ $available ชิ้น',
        );
        return;
      }
      items.add({'lineId': lineId, 'partId': line['partId'], 'qty': qty});
    }

    final confirm = await showConfirmDialog(
      context,
      title: 'สร้าง Pick Order',
      message: 'สร้าง Pick Order จาก ${items.length} รายการ?',
      confirmLabel: 'สร้าง',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);
    final result = await _api.createTestOrder(
      operatorId: widget.userId,
      items: items,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สร้างไม่สำเร็จ');
      return;
    }

    final orderId = result.data!['pickOrderId'] as String;
    showSuccessSnackbar(context,
        'สร้าง $orderId สำเร็จ — Robot กำลังเตรียมขน Pallet (3s)');
    await _loadLines();
    _scheduleRobotArrival(orderId);
  }

  /// จำลอง robot ขน pallet มาถึง station หลัง create order N วินาที
  void _scheduleRobotArrival(String pickOrderId) {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final res = await _api.notifyArrival(pickOrderId);
      if (!mounted) return;
      if (res.success) {
        showSuccessSnackbar(
          context,
          '🤖 Robot ถึงแล้ว — $pickOrderId พร้อม Pick',
        );
      } else {
        showErrorDialog(context,
            message:
                res.error ?? 'จำลอง robot arrival ไม่สำเร็จ ($pickOrderId)');
      }
    });
  }

  Future<void> _quickCreate() async {
    if (_lines.isEmpty) {
      showErrorDialog(context, message: 'ไม่มีรายการให้สร้าง');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final lineId = line['lineId'] as int;
      final qty = int.tryParse(_qtyCtrl[lineId]?.text.trim() ?? '') ??
          (line['availableQty'] as int);
      items.add({
        'lineId': lineId,
        'partId': line['partId'],
        'qty': qty,
      });
    }

    setState(() => _loading = true);
    final result = await _api.createTestOrder(
      operatorId: widget.userId,
      items: items,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สร้างไม่สำเร็จ');
      return;
    }

    final orderId = result.data!['pickOrderId'] as String;
    showSuccessSnackbar(
        context, 'Quick: สร้าง $orderId — Robot กำลังเตรียมขน Pallet (3s)');
    await _loadLines();
    _scheduleRobotArrival(orderId);
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _lines.length) {
        _selected.clear();
      } else {
        _selected.addAll(_lines.map((l) => l['lineId'] as int));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'สร้าง Pick Order (Manual)',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังโหลด...',
          child: Column(
            children: [
              // ── Header ── (long-press icon to toggle hidden Quick Create)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: AppTheme.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    GestureDetector(
                      onLongPress: () {
                        setState(() => _showQuickCreate = !_showQuickCreate);
                        showSuccessSnackbar(
                          context,
                          _showQuickCreate
                              ? 'Quick Create: ON'
                              : 'Quick Create: OFF',
                        );
                      },
                      child: Icon(
                        MdiIcons.flaskOutline,
                        color: _showQuickCreate
                            ? AppTheme.warning
                            : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onLongPress: () {
                        setState(() =>
                            _showReturnPallet = !_showReturnPallet);
                        showSuccessSnackbar(
                          context,
                          _showReturnPallet
                              ? 'Return Pallet: ON'
                              : 'Return Pallet: OFF',
                        );
                      },
                      child: Icon(
                        MdiIcons.packageVariantClosed,
                        color: _showReturnPallet
                            ? AppTheme.warning
                            : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'เลือกสินค้าที่ต้องการ Pick (${_selected.length}/${_lines.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _toggleAll,
                      child: Text(
                        _selected.length == _lines.length
                            ? 'Clear All'
                            : 'Select All',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadLines,
                    ),
                  ],
                ),
              ),

              // ── List ──
              Expanded(
                child: _lines.isEmpty
                    ? Center(
                        child: Text(
                          'ไม่มีสินค้าที่ PALLETIZED\nหรือถูก allocate หมดแล้ว',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textGrey(context)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _lines.length,
                        itemBuilder: (_, i) => _buildLineItem(_lines[i]),
                      ),
              ),

              // ── Create Button ──
              if (_selected.isNotEmpty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PrimaryButton(
                      label: 'สร้าง Pick Order (${_selected.length} รายการ)',
                      icon: MdiIcons.playlistPlus,
                      onPressed: _createOrder,
                    ),
                  ),
                ),

              // ── Quick Create (hidden) — long-press flask icon to toggle ──
              if (_showQuickCreate && _selected.isEmpty && _lines.isNotEmpty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: _quickCreate,
                      icon: const Icon(Icons.flash_on, size: 18),
                      label: Text(
                        'Quick Create (${_lines.length} lines)',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

              // ── Return Pallet (hidden) — long-press box icon to toggle ──
              if (_showReturnPallet)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(MdiIcons.packageVariantClosed,
                                  size: 18, color: AppTheme.warning),
                              const SizedBox(width: 6),
                              const Text(
                                'ส่ง Pallet ไปปลายทาง',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // ── Destination picker ──
                          Row(
                            children: [
                              Expanded(
                                child: _destChip(
                                  label: 'ASRS',
                                  icon: Icons.warehouse_outlined,
                                  selected: _returnDest == 'ASRS',
                                  onTap: () => setState(
                                      () => _returnDest = 'ASRS'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _destChip(
                                  label: 'ZONE_PACK',
                                  icon: Icons.inventory_2_outlined,
                                  selected: _returnDest == 'ZONE_PACK',
                                  onTap: () => setState(
                                      () => _returnDest = 'ZONE_PACK'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _destChip(
                                  label: 'PICK',
                                  icon: MdiIcons.handBackRight,
                                  selected: _returnDest == 'PICK',
                                  onTap: () => setState(
                                      () => _returnDest = 'PICK'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _returnPalletCtrl,
                            focusNode: _returnPalletFocus,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Pallet ID',
                              hintText: 'scan / type → กดปุ่ม',
                              prefixIcon: const Icon(Icons.qr_code_scanner,
                                  size: 18),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendPallet(),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _sendPallet,
                            icon: Icon(MdiIcons.packageVariantClosedCheck,
                                size: 18),
                            label: Text(
                              'ส่งไป $_returnDest',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warning,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineItem(Map<String, dynamic> line) {
    final lineId = line['lineId'] as int;
    final selected = _selected.contains(lineId);
    final partId = line['partId'] as String;
    final itemDesc = line['itemDesc'] as String;
    final palletId = line['palletId'] as String;
    final palletType = line['palletType'] as String;
    final available = line['availableQty'] as int;
    final owner = line['owner'] as String;
    final brand = (line['brand'] as String?) ?? '';
    final lotNumber = line['lotNumber'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      color: selected ? AppTheme.primary.withValues(alpha: 0.03) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            selected ? _selected.remove(lineId) : _selected.add(lineId);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? AppTheme.primary : Colors.grey,
              ),
              const SizedBox(width: 10),
              PartThumbnail(imageUrl: line['imageUrl'] as String?, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      itemDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (lotNumber != null && lotNumber.isNotEmpty) ...[
                          Icon(
                            MdiIcons.tagOutline,
                            size: 12,
                            color: AppTheme.textGrey(context),
                          ),
                          const SizedBox(width: 2),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textGrey(context),
                              ),
                              children: [
                                const TextSpan(
                                  text: "Batch No.",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: " : $lotNumber"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '$owner / $brand',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(MdiIcons.packageVariantClosed, palletId),
                        const SizedBox(width: 6),
                        _InfoChip(MdiIcons.tag, palletType),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Qty input
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _qtyCtrl[lineId],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  enabled: selected,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    suffixText: '/$available',
                    suffixStyle: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textGrey(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textGrey(context)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textGrey(context)),
          ),
        ],
      ),
    );
  }
}
