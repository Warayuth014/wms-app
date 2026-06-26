import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/part_thumbnail.dart';

enum _PackState { scanPallet, packList, orderList, orderParts, success }

class PackingScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String? initialPalletId;

  const PackingScreen({
    super.key,
    required this.userId,
    required this.fullName,
    this.initialPalletId,
  });

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  static const Color _packBorder = Color(0xFFDCE6F2);
  static const Color _packTextDark = Color(0xFF1F2937);
  static const Color _packTextMuted = Color(0xFF6B7280);
  static const Color _packChipBg = Color(0xFFEAF3FF);
  static const Color _packSuccess = Color(0xFF22A06B);
  static const double _packSerialHeaderHeight = 32;
  static const double _packSerialRowHeight = 42;
  static const int _packSerialVisibleRowLimit = 5;

  final _api = ApiService();
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  final _partScanCtrl = TextEditingController();
  final _partScanFocus = FocusNode();
  final _serialScanCtrl = TextEditingController();
  final _serialScanFocus = FocusNode();

  _PackState _state = _PackState.scanPallet;
  bool _loading = false;

  // data
  PackingPalletResponse? _palletResp;
  PackingDetailResponse? _packDetail;
  PackingOrderResponse? _orderResp;
  ConfirmPackResponse? _confirmResult;

  // current selection
  String _currentPackingId = '';
  String _currentPickOrderId = '';
  String? _selectedPartId;
  // Serial numbers collected for each part (keyed by partId)
  final Map<String, List<String>> _collectedSerials = {};
  final Set<String> _expandedSerialPartIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPalletId != null &&
          widget.initialPalletId!.isNotEmpty) {
        _scanCtrl.text = widget.initialPalletId!;
        _scanPallet();
      } else {
        _scanFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _partScanCtrl.dispose();
    _partScanFocus.dispose();
    _serialScanCtrl.dispose();
    _serialScanFocus.dispose();
    super.dispose();
  }

  // ── API calls ──────────────────────────────────

  Future<void> _scanPallet() async {
    final palletId = _scanCtrl.text.trim().toUpperCase();
    if (palletId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.scanPalletForPacking(palletId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ไม่พบ Pallet');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    setState(() {
      _palletResp = result.data;
      _state = _PackState.packList;
    });
  }

  Future<void> _openPack(String packingId) async {
    setState(() => _loading = true);
    final result = await _api.getPack(packingId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลด Pack ไม่สำเร็จ');
      return;
    }

    setState(() {
      _currentPackingId = packingId;
      _packDetail = result.data;
      // ถ้ามี Order เดียว เข้า Order เลย
      if (result.data!.orders.length == 1) {
        _openOrder(result.data!.orders.first.pickOrderId);
      } else {
        _state = _PackState.orderList;
      }
    });
  }

  Future<void> _openOrder(String pickOrderId) async {
    setState(() => _loading = true);
    final result = await _api.getPackOrder(
      packingId: _currentPackingId,
      pickOrderId: pickOrderId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(
          context, message: result.error ?? 'โหลด Order ไม่สำเร็จ');
      return;
    }

    setState(() {
      _orderResp = result.data;
      _currentPickOrderId = pickOrderId;
      _selectedPartId = null;
      _collectedSerials.clear();
      _expandedSerialPartIds.clear();
      _partScanCtrl.clear();
      _serialScanCtrl.clear();
      _state = _PackState.orderParts;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _partScanFocus.requestFocus();
    });
  }

  Future<void> _scanPart() async {
    final partId = _partScanCtrl.text.trim().toUpperCase();
    if (partId.isEmpty) return;

    final part = _orderResp?.parts.where((p) => p.partId == partId).firstOrNull;
    if (part == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" ใน Order นี้');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    if (part.isDone) {
      showErrorDialog(context, message: 'Part "$partId" สแกนครบแล้ว');
      _partScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    setState(() {
      _selectedPartId = partId;
      _partScanCtrl.text = partId;
    });
    _serialScanFocus.requestFocus();
  }

  void _scanSerial() {
    final partId = _partScanCtrl.text.trim().toUpperCase();
    final serialNo = _serialScanCtrl.text.trim().toUpperCase();
    if (partId.isEmpty) {
      showWarningSnackbar(context, 'กรุณาสแกน Part ก่อน');
      _partScanFocus.requestFocus();
      return;
    }
    if (serialNo.isEmpty) {
      showWarningSnackbar(context, 'กรุณาสแกน S/N');
      _serialScanFocus.requestFocus();
      return;
    }

    final part = _orderResp?.parts.where((p) => p.partId == partId).firstOrNull;
    if (part == null) {
      showErrorDialog(context, message: 'ไม่พบ Part "$partId" ใน Order นี้');
      _partScanCtrl.clear();
      _serialScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    if (part.isDone) {
      showWarningSnackbar(context, 'Part $partId แพ็คครบแล้ว');
      _serialScanCtrl.clear();
      _partScanFocus.requestFocus();
      return;
    }

    final serials = _collectedSerials.putIfAbsent(partId, () => <String>[]);
    if (serials.contains(serialNo)) {
      showWarningSnackbar(context, 'S/N "$serialNo" สแกนไปแล้ว');
      _serialScanCtrl.clear();
      _serialScanFocus.requestFocus();
      return;
    }

    if (!part.availableSerials.contains(serialNo)) {
      showErrorDialog(
        context,
        message: 'S/N "$serialNo" ไม่อยู่บน Pallet นี้สำหรับ Part "$partId"',
      );
      _serialScanCtrl.clear();
      _serialScanFocus.requestFocus();
      return;
    }

    if (serials.length >= part.remaining) {
      showWarningSnackbar(
        context,
        'Part $partId สแกนครบ ${part.remaining} ชิ้นแล้ว',
      );
      _serialScanCtrl.clear();
      _serialScanFocus.requestFocus();
      return;
    }

    setState(() {
      _selectedPartId = partId;
      serials.add(serialNo);
    });
    _serialScanCtrl.clear();
    _serialScanFocus.requestFocus();
  }

  /// แบนเนอร์ "ดูทั้งหมด" ที่ขึ้นเมื่อ filter อยู่ — แตะเพื่อเคลียร์ selection
  Widget _buildPackShowAllBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() {
          _selectedPartId = null;
          _partScanCtrl.clear();
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'แสดงเฉพาะ part ที่เลือก',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              Text(
                'ดูทั้งหมด',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.close, size: 14, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _selectPartForPackScan(String partId) {
    final part = _orderResp?.parts.where((p) => p.partId == partId).firstOrNull;
    if (part == null || part.isDone) return;

    setState(() {
      if (_selectedPartId == partId) {
        // tap ตัวที่ select อยู่ → deselect (กลับไปดูทั้งหมด)
        _selectedPartId = null;
        _partScanCtrl.clear();
      } else {
        _selectedPartId = partId;
        _partScanCtrl.text = partId;
      }
    });
    if (_selectedPartId != null) {
      _serialScanFocus.requestFocus();
    }
  }

  void _removeCollectedSerial(String partId, String serialNo) {
    setState(() {
      final serials = _collectedSerials[partId];
      serials?.remove(serialNo);
      if (serials == null || serials.isEmpty) {
        _collectedSerials.remove(partId);
        _expandedSerialPartIds.remove(partId);
        if (_selectedPartId == partId) {
          _selectedPartId = null;
        }
      }
    });
    _serialScanFocus.requestFocus();
  }

  void _toggleCollectedSerials(String partId) {
    setState(() {
      if (_expandedSerialPartIds.contains(partId)) {
        _expandedSerialPartIds.remove(partId);
      } else {
        _expandedSerialPartIds.add(partId);
      }
    });
  }

  Future<void> _copyAndFillSerialForTest(
    String partId,
    String serialNo,
  ) async {
    await Clipboard.setData(ClipboardData(text: serialNo));
    if (!mounted) return;
    setState(() {
      _selectedPartId = partId;
      _partScanCtrl.text = partId;
      _serialScanCtrl.text = serialNo;
    });
    _serialScanFocus.requestFocus();
    showSuccessSnackbar(context, 'คัดลอก S/N "$serialNo" แล้ว');
  }

  void _showAvailableSerialsSheet() {
    final parts = _orderResp?.parts
            .where((part) => part.availableSerials.isNotEmpty && !part.isDone)
            .toList() ??
        const <PackingPartItem>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'S/N สำหรับทดสอบ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'ปิด',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: parts.isEmpty
                          ? Center(
                              child: Text(
                                'ยังไม่มี S/N ที่พร้อมแพ็ค',
                                style: TextStyle(
                                  color: AppTheme.textGrey(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: parts.length,
                              itemBuilder: (context, index) {
                                final part = parts[index];
                                final collected =
                                    _collectedSerials[part.partId] ??
                                        const <String>[];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              part.partId,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${collected.length}/${part.remaining}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...part.availableSerials.map((serialNo) {
                                        final alreadyCollected =
                                            collected.contains(serialNo);
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            color: alreadyCollected
                                                ? _packSuccess
                                                    .withValues(alpha: 0.1)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: alreadyCollected
                                                  ? _packSuccess.withValues(
                                                      alpha: 0.45,
                                                    )
                                                  : _packBorder,
                                            ),
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            visualDensity:
                                                VisualDensity.compact,
                                            title: Text(
                                              serialNo,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              tooltip: 'คัดลอก',
                                              icon: const Icon(
                                                Icons.copy,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(sheetContext);
                                                _copyAndFillSerialForTest(
                                                  part.partId,
                                                  serialNo,
                                                );
                                              },
                                            ),
                                            onTap: () {
                                              Navigator.pop(sheetContext);
                                              _copyAndFillSerialForTest(
                                                part.partId,
                                                serialNo,
                                              );
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmPart(String partId, int qty) async {
    final serials = _collectedSerials[partId] ?? const <String>[];
    if (serials.length != qty) {
      showErrorDialog(context,
          message:
              'จำนวน S/N (${serials.length}) ไม่ตรงกับจำนวนที่ต้อง Pack ($qty)');
      return;
    }

    setState(() => _loading = true);
    final result = await _api.scanPackPart(
      packingId: _currentPackingId,
      pickOrderId: _currentPickOrderId,
      partId: partId,
      qty: qty,
      operatorId: widget.userId,
      serialNumbers: List<String>.of(serials),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สแกนไม่สำเร็จ');
      return;
    }

    final resp = result.data!;

    // Pack auto-finalize เมื่อสแกนชิ้นสุดท้ายครบทุก Order → ไปหน้า Pack Complete
    if (resp.packFinalized) {
      setState(() {
        _confirmResult = ConfirmPackResponse(
          packingId: resp.packingId,
          status: 'DONE',
          trackingId: resp.trackingId,
          palletShipped: resp.palletReleased,
          completedAt: DateTime.now(),
          message: resp.palletReleased
              ? 'Pack สำเร็จ — Pallet เปล่าพร้อมใช้ใหม่'
              : 'Pack สำเร็จ (ยังเหลือ Pack อื่นใน Pallet)',
        );
        _selectedPartId = null;
        _collectedSerials.remove(partId);
        _expandedSerialPartIds.remove(partId);
        _partScanCtrl.clear();
        _serialScanCtrl.clear();
        _state = _PackState.success;
      });
      return;
    }

    setState(() {
      _orderResp = resp;
      _selectedPartId = null;
      _collectedSerials.remove(partId);
      _expandedSerialPartIds.remove(partId);
      _partScanCtrl.clear();
      _serialScanCtrl.clear();
    });
    _partScanFocus.requestFocus();
  }

  Future<void> _confirmCollectedPack() async {
    final order = _orderResp;
    if (order == null) return;

    final readyParts = order.parts
        .where((part) =>
            !part.isDone &&
            part.remaining > 0 &&
            (_collectedSerials[part.partId]?.length ?? 0) == part.remaining)
        .toList();

    if (readyParts.isEmpty) {
      showWarningSnackbar(
        context,
        'กรุณาสแกน S/N ให้ครบอย่างน้อย 1 รายการก่อนยืนยัน',
      );
      _serialScanFocus.requestFocus();
      return;
    }

    for (final part in readyParts) {
      await _confirmPart(part.partId, part.remaining);
      if (!mounted || _state != _PackState.orderParts) return;
    }
  }

  Future<void> _refreshPackList() async {
    // reload pallet data แล้วกลับหน้า packList
    setState(() => _loading = true);
    final palletId = _palletResp!.palletId;
    final result = await _api.scanPalletForPacking(palletId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      // pallet อาจ shipped ไปแล้ว
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่สำเร็จ');
      _resetAll();
      return;
    }

    setState(() {
      _palletResp = result.data;
      _packDetail = null;
      _currentPackingId = '';
      _currentPickOrderId = '';
      _orderResp = null;
      _selectedPartId = null;
      _collectedSerials.clear();
      _expandedSerialPartIds.clear();
      _state = _PackState.packList;
    });
  }

  void _resetAll() {
    setState(() {
      _palletResp = null;
      _packDetail = null;
      _orderResp = null;
      _confirmResult = null;
      _currentPackingId = '';
      _currentPickOrderId = '';
      _selectedPartId = null;
      _collectedSerials.clear();
      _expandedSerialPartIds.clear();
      _scanCtrl.clear();
      _partScanCtrl.clear();
      _serialScanCtrl.clear();
      _state = _PackState.scanPallet;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _PackState.scanPallet,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: WmsAppBar(title: 'Packing', userName: widget.fullName),
        body: SafeArea(
          top: false,
          child: LoadingOverlay(
            loading: _loading,
            message: 'กำลังประมวลผล...',
            child: _state == _PackState.orderParts
                ? _buildOrderParts()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_state == _PackState.scanPallet)
                          _buildScanPallet(),
                        if (_state == _PackState.packList) _buildPackList(),
                        if (_state == _PackState.orderList) _buildOrderList(),
                        if (_state == _PackState.success) _buildSuccess(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    setState(() {
      switch (_state) {
        case _PackState.packList:
          _resetAll();
          break;
        case _PackState.orderList:
          _state = _PackState.packList;
          _packDetail = null;
          _currentPackingId = '';
          break;
        case _PackState.orderParts:
          // ถ้า Pack มีหลาย Order กลับไป orderList แทน packList
          if (_packDetail != null && _packDetail!.orders.length > 1) {
            _state = _PackState.orderList;
          } else {
            _state = _PackState.packList;
            _packDetail = null;
            _currentPackingId = '';
          }
          _orderResp = null;
          _currentPickOrderId = '';
          _selectedPartId = null;
          _collectedSerials.clear();
          _expandedSerialPartIds.clear();
          _partScanCtrl.clear();
          _serialScanCtrl.clear();
          break;
        case _PackState.success:
          _resetAll();
          break;
        default:
          break;
      }
    });
  }

  // ── State 1: Scan Pallet ──────────────────────────────────

  Widget _buildScanPallet() {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.barcodeScan, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Scan Pallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สแกน Pallet ที่ต้องการแพ็คสินค้า',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Pallet ID',
            hint: 'Scan Pallet ID',
            controller: _scanCtrl,
            focusNode: _scanFocus,
            onSubmit: _scanPallet,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Scan',
            icon: Icons.search,
            onPressed: _scanPallet,
          ),
        ],
      ),
    );
  }

  // ── State 2: Pack List ──────────────────────────────────

  Widget _buildPackList() {
    final pallet = _palletResp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pallet header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.packageVariantClosed,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(pallet.palletId,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _statusChip(pallet.status),
                  ],
                ),
                if (pallet.location != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Location: ${pallet.location}',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Pack cards — เฉพาะที่ยัง OPEN (DONE = finalize แล้ว ไป Check-in ต่อ)
        ...pallet.packs.where((p) => p.status == 'OPEN').map((pack) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.warning,
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(pack.packingId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusChip(pack.status),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openPack(pack.packingId),
              ),
            )),
        if (pallet.packs.every((p) => p.status != 'OPEN'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppTheme.success, size: 40),
                    const SizedBox(height: 8),
                    const Text('Pack ทุกกล่องเสร็จแล้ว',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('ไปสแกน Check-in ต่อได้เลย',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ),
        if (pallet.packs.every((p) => p.isDone))
          const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _resetAll,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('สแกน Pallet อื่น'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textGrey(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── State 3a: Order List (when Pack has multiple Orders) ──────────────────

  Widget _buildOrderList() {
    final pack = _packDetail!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.packageVariantClosed,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pack.packingId,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _statusChip(pack.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Pallet: ${pack.palletId}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Orders: ${pack.orders.length}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'เลือก Order เพื่อ Pack',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey(context)),
          ),
        ),
        ...pack.orders.map((order) => Card(
              color: order.isDone
                  ? AppTheme.success.withValues(alpha: 0.06)
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      order.isDone ? AppTheme.success : AppTheme.secondary,
                  child: Icon(
                    order.isDone
                        ? Icons.check
                        : MdiIcons.clipboardListOutline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(order.pickOrderId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Parts: ${order.partDoneCount}/${order.partCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusChip(order.status),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openOrder(order.pickOrderId),
              ),
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('กลับ'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textGrey(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── State 3: Order Parts (scan + list) ──────────────────────────────────

  Widget _buildOrderParts() {
    final order = _orderResp!;
    final allDone = order.parts.every((p) => p.isDone);
    final totalNeeded =
        order.parts.fold<int>(0, (sum, part) => sum + part.requiredQty);
    final totalPacked = order.parts.fold<int>(
      0,
      (sum, part) {
        final collected = _collectedSerials[part.partId]?.length ?? 0;
        final packedForPart =
            (part.scannedQty + collected).clamp(0, part.requiredQty).toInt();
        return sum + packedForPart;
      },
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPackContextCard(order, totalPacked, totalNeeded),
                const SizedBox(height: 12),
                if (order.status != 'DONE') _buildPackScannerCard(),
                const SizedBox(height: 14),
                _buildPackListHeader(totalPacked, totalNeeded),
                const SizedBox(height: 8),
                if (_selectedPartId != null) _buildPackShowAllBanner(),
                ...(() {
                  // filter ตาม select + sort: expanded ขึ้นล่างสุด
                  final list = order.parts
                      .where((p) =>
                          _selectedPartId == null ||
                          p.partId == _selectedPartId)
                      .toList()
                    ..sort((a, b) {
                      final ae = _expandedSerialPartIds.contains(a.partId) ? 1 : 0;
                      final be = _expandedSerialPartIds.contains(b.partId) ? 1 : 0;
                      return ae.compareTo(be);
                    });
                  return list.map(_buildPackItemCard);
                })(),
              ],
            ),
          ),
        ),
        _buildPackBottomAction(allDone),
      ],
    );
  }

  Widget _buildPackContextCard(
    PackingOrderResponse order,
    int totalPacked,
    int totalNeeded,
  ) {
    final palletId = _packDetail?.palletId ?? _palletResp?.palletId ?? '-';
    final pct = totalNeeded > 0 ? totalPacked / totalNeeded : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _packCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MdiIcons.clipboardListOutline,
                color: AppTheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pack: $_currentPackingId',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _packTextDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _packStatusPill(order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Order: $_currentPickOrderId',
            style: const TextStyle(fontSize: 13, color: _packTextMuted),
          ),
          Text(
            'Pallet: $palletId',
            style: const TextStyle(fontSize: 13, color: _packTextMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$totalPacked / $totalNeeded',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _packTextDark,
                ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 13, color: _packTextMuted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(
                pct >= 1 ? _packSuccess : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackScannerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _packCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สแกน Part',
            style: TextStyle(
              fontSize: 12,
              color: _packTextMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _partScanCtrl,
            focusNode: _partScanFocus,
            textCapitalization: TextCapitalization.characters,
            decoration: _packScanInputDecoration(
              label: 'Part No.',
              hint: 'เช่น PT-1001',
              icon: Icons.qr_code_scanner,
            ),
            onSubmitted: (_) => _scanPart(),
          ),
          const SizedBox(height: 12),
          const Text(
            'สแกน S/N',
            style: TextStyle(
              fontSize: 12,
              color: _packTextMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _serialScanCtrl,
            focusNode: _serialScanFocus,
            textCapitalization: TextCapitalization.characters,
            decoration: _packScanInputDecoration(
              label: 'Serial Number',
              hint: 'กรอกหรือสแกน S/N สินค้า',
              icon: Icons.confirmation_number,
            ),
            onSubmitted: (_) => _scanSerial(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _scanSerial,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'เพิ่ม S/N',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _packScanInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _packBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppTheme.primary,
          width: 1.5,
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildPackListHeader(int totalPacked, int totalNeeded) {
    return Row(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          color: _packTextDark,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'รายการใน Pack',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _packTextDark,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _packChipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'แพ็คแล้ว $totalPacked/$totalNeeded',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: 'แสดง S/N สำหรับทดสอบ',
          visualDensity: VisualDensity.compact,
          onPressed: _showAvailableSerialsSheet,
          icon: Icon(
            Icons.visibility_outlined,
            size: 20,
            color: AppTheme.textGrey(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPackItemCard(PackingPartItem part) {
    final collected = _collectedSerials[part.partId] ?? const <String>[];
    final currentPacked =
        (part.scannedQty + collected.length).clamp(0, part.requiredQty).toInt();
    final isSelected = _selectedPartId == part.partId || collected.isNotEmpty;
    final isComplete = part.isDone || currentPacked >= part.requiredQty;
    final progress = part.requiredQty > 0
        ? (currentPacked / part.requiredQty).clamp(0.0, 1.0)
        : 0.0;
    final showSerials = _expandedSerialPartIds.contains(part.partId);
    final selectedColor = isComplete ? _packSuccess : AppTheme.primary;
    final bodyTextColor =
        isSelected || part.isDone ? _packTextDark : _packTextMuted;

    return GestureDetector(
      onTap: () => _selectPartForPackScan(part.partId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected || part.isDone
                ? selectedColor.withValues(alpha: 0.55)
                : _packBorder,
            width: isSelected || part.isDone ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected || part.isDone
                  ? selectedColor.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected || part.isDone ? 12 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isSelected || part.isDone)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: selectedColor),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSelected || part.isDone ? 18 : 12,
                12,
                12,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          isSelected || part.isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected || part.isDone
                              ? selectedColor
                              : AppTheme.textGrey(context),
                          size: isSelected || part.isDone ? 24 : 22,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PartThumbnail(imageUrl: part.imageUrl, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          part.partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _packTextDark,
                          ),
                        ),
                      ),
                      _packStatusPill(part.isDone ? 'DONE' : 'PACK'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.itemDesc,
                          style: TextStyle(
                            fontSize: 13,
                            color: bodyTextColor,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${part.owner} / ${part.brand}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: bodyTextColor,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'บน Pallet: ${part.requiredQty}',
                              style: TextStyle(
                                fontSize: 13,
                                color: bodyTextColor,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            Text(
                              'ต้องการ: ${part.remaining}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: part.availableSerials.isEmpty
                            ? null
                            : () => _toggleCollectedSerials(part.partId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isComplete
                                ? _packSuccess.withValues(alpha: 0.12)
                                : _packChipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$currentPacked/${part.requiredQty}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isComplete
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
                              if (part.availableSerials.isNotEmpty) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  showSerials
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isComplete
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation(_packSuccess),
                    ),
                  ),
                  if (showSerials) ...[
                    const SizedBox(height: 8),
                    _buildPackSerialTable(
                      partId: part.partId,
                      availableSerials: part.availableSerials,
                      collectedSerials: collected,
                      actionColor: selectedColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง S/N pool ทั้งหมดของ part บน pallet + highlight อันที่ scan แล้ว
  /// - Picked: bg เขียวอ่อน + ✓ icon + text เขียวเข้ม
  /// - Unpicked: bg ขาว + text grey
  /// - Tap row ที่ picked = ยกเลิก scan (ลบออก)
  Widget _buildPackSerialTable({
    required String partId,
    required List<String> availableSerials,
    required List<String> collectedSerials,
    required Color actionColor,
  }) {
    final collectedSet = collectedSerials.toSet();
    final total = availableSerials.length;
    final collected = collectedSet.length;
    final visibleRows = total > _packSerialVisibleRowLimit
        ? _packSerialVisibleRowLimit
        : total;
    final rowCount = visibleRows == 0 ? 1 : visibleRows;

    return Container(
      height: _packSerialHeaderHeight + (rowCount * _packSerialRowHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _packBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header ──
          Container(
            height: _packSerialHeaderHeight,
            color: const Color(0xFFF3F7FC),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 34,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _packTextMuted,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'S/N',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _packTextMuted,
                    ),
                  ),
                ),
                Text(
                  'แพ็คแล้ว $collected/$total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: collected > 0 ? _packSuccess : _packTextMuted,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          // ── Rows ──
          Expanded(
            child: total == 0
                ? const Center(
                    child: Text(
                      'ไม่มี S/N pool',
                      style: TextStyle(
                          fontSize: 12,
                          color: _packTextMuted,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemExtent: _packSerialRowHeight,
                    physics: total > _packSerialVisibleRowLimit
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: total,
                    itemBuilder: (context, index) {
                      final serialNo = availableSerials[index];
                      final isCollected = collectedSet.contains(serialNo);
                      final isLast = index == total - 1;

                      return InkWell(
                        onTap: isCollected
                            ? () => _removeCollectedSerial(partId, serialNo)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCollected
                                ? _packSuccess.withValues(alpha: 0.10)
                                : Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: isLast
                                    ? Colors.transparent
                                    : _packBorder,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCollected
                                        ? _packSuccess
                                        : _packTextMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  serialNo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCollected
                                        ? _packSuccess
                                        : _packTextDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 42,
                                height: _packSerialRowHeight,
                                child: isCollected
                                    ? Icon(Icons.check_circle,
                                        size: 18, color: _packSuccess)
                                    : Icon(
                                        Icons.radio_button_unchecked,
                                        size: 16,
                                        color: AppTheme.textGrey(context)
                                            .withValues(alpha: 0.4),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackBottomAction(bool allDone) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        border: Border(
          top: BorderSide(color: Color(0xFFE4EAF2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: allDone ? _refreshPackList : _confirmCollectedPack,
            icon: Icon(
              allDone ? Icons.check_circle_outline : Icons.check_rounded,
            ),
            label: Text(
              allDone ? 'Order นี้เสร็จแล้ว' : 'ยืนยัน Pack',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: allDone ? _packSuccess : AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: AppTheme.primary.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _packCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _packBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _packStatusPill(String text) {
    final isDone = text == 'DONE';
    final color = isDone ? _packSuccess : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ── State 4: Success ──────────────────────────────────

  Widget _buildSuccess() {
    final result = _confirmResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text('Pack Complete',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (result.trackingId != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กำลังปริ้น Tracking...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.print, size: 20),
              label: Text('Print Tracking: ${result.trackingId}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: result.palletShipped ? _resetAll : _refreshPackList,
            icon: Icon(
              result.palletShipped
                  ? MdiIcons.barcodeScan
                  : MdiIcons.packageVariantClosed,
              size: 20,
            ),
            label: Text(
              result.palletShipped
                  ? 'Pack Pallet ถัดไป'
                  : 'แพ็คกล่องถัดไปของ Pallet นี้',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home_outlined, size: 18),
          label: const Text('กลับหน้าหลัก'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textGrey(context),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────

  Widget _statusChip(String status) {
    final color = switch (status) {
      'SHIPPED' => AppTheme.success,
      'DONE' => AppTheme.primary,
      'STAGED' => AppTheme.secondary,
      'OPEN' || 'PACKED' => AppTheme.warning,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Serial Select Page ──────────────────────────────────

class _SerialSelectPage extends StatefulWidget {
  final String partId;
  final int requiredQty;
  final List<String> available;
  final List<String> initial;

  const _SerialSelectPage({
    required this.partId,
    required this.requiredQty,
    required this.available,
    required this.initial,
  });

  @override
  State<_SerialSelectPage> createState() => _SerialSelectPageState();
}

class _SerialSelectPageState extends State<_SerialSelectPage> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  late List<String> _scanned;
  late Set<String> _availableSet;

  @override
  void initState() {
    super.initState();
    _scanned = List.of(widget.initial);
    _availableSet = widget.available.toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  void _onScan() {
    final sn = _scanCtrl.text.trim();
    if (sn.isEmpty) return;

    if (_scanned.length >= widget.requiredQty) {
      showErrorDialog(context,
          message: 'สแกนครบ ${widget.requiredQty} ชิ้นแล้ว');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    if (!_availableSet.contains(sn)) {
      showErrorDialog(context,
          message: 'S/N "$sn" ไม่อยู่บน Pallet นี้สำหรับ ${widget.partId}');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    if (_scanned.contains(sn)) {
      showErrorDialog(context, message: 'S/N "$sn" ถูกสแกนไปแล้ว');
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }

    setState(() => _scanned.add(sn));
    _scanCtrl.clear();
    _scanFocus.requestFocus();
  }

  void _remove(String sn) {
    setState(() => _scanned.remove(sn));
    _scanFocus.requestFocus();
  }

  void _clearAll() {
    setState(() => _scanned.clear());
    _scanFocus.requestFocus();
  }

  // DEV: mock autofill ทั้งหมด (long-press ที่ title เพื่อเรียก)
  void _mockFillAll() {
    final take = widget.available.take(widget.requiredQty).toList();
    setState(() {
      _scanned
        ..clear()
        ..addAll(take);
    });
  }

  Future<void> _save() async {
    if (_scanned.isEmpty) {
      Navigator.pop(context, <String>[]);
      return;
    }

    if (_scanned.length != widget.requiredQty) {
      showErrorDialog(context,
          message:
              'ต้องสแกนครบ ${widget.requiredQty} ชิ้น (สแกนแล้ว ${_scanned.length})');
      return;
    }

    Navigator.pop(context, List.of(_scanned));
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _scanned.length >= widget.requiredQty;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _mockFillAll,
          behavior: HitTestBehavior.opaque,
          child: Text('สแกน S/N: ${widget.partId}'),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('S/N ที่สแกน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            )),
                        const Spacer(),
                        Text('${_scanned.length} / ${widget.requiredQty}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isComplete
                                  ? AppTheme.success
                                  : AppTheme.primary,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.requiredQty > 0
                            ? _scanned.length / widget.requiredQty
                            : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(
                            isComplete ? AppTheme.success : AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _scanCtrl,
                            focusNode: _scanFocus,
                            enabled: !isComplete,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'สแกน S/N',
                              prefixIcon: Icon(MdiIcons.barcodeScan),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => _onScan(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: isComplete ? null : _onScan,
                          icon: const Icon(Icons.send,
                              color: AppTheme.primary),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    if (_scanned.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('ล้างทั้งหมด',
                              style: TextStyle(fontSize: 13)),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.warning),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _scanned.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(MdiIcons.barcodeScan,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('ยังไม่มี S/N ที่สแกน',
                                style:
                                    TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                                'สแกนให้ครบ ${widget.requiredQty} ชิ้น หรือกดกลับเพื่อข้าม',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _scanned.length,
                        itemBuilder: (_, i) {
                          final sn = _scanned[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color:
                                AppTheme.primary.withValues(alpha: 0.06),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primary,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                              title: Text(sn,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    color: AppTheme.warning, size: 20),
                                onPressed: () => _remove(sn),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    isComplete
                        ? 'ยืนยัน (${_scanned.length} ชิ้น)'
                        : _scanned.isEmpty
                            ? 'ข้าม (ไม่เก็บ S/N)'
                            : 'ยืนยัน (${_scanned.length}/${widget.requiredQty})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isComplete
                        ? AppTheme.success
                        : _scanned.isEmpty
                            ? AppTheme.textGrey(context)
                            : AppTheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
