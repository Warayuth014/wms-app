import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../services/api_service.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';
import '../../models/station_info.dart';
import '../pallet/pallet_items_page.dart';
import '../destination/station_destination_selector.dart';
import '../pallet/station_pallet_info_card.dart';
import '../destination/station_wrapping_toggle.dart';

class StationSheet extends StatefulWidget {
  final StationInfo station;
  final String userId;
  final VoidCallback onConfirmed;

  const StationSheet({
    super.key,
    required this.station,
    required this.userId,
    required this.onConfirmed,
  });

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  final _palletController = TextEditingController();
  final _api = ApiService();

  PutawayPalletInfo? _pallet;
  bool _loadingPallet = false;
  bool _loadingConfirm = false;

  String _selectedDestination = 'ASRS';
  bool _wrappingRequired = false;

  String get _effectiveDestination =>
      widget.station.fixedDestination ?? _selectedDestination;

  @override
  void dispose() {
    _palletController.dispose();
    super.dispose();
  }

  bool get _isReceive => widget.station.pwRole == PWRole.receive;

  Future<void> _scanPallet() async {
    final palletId = _palletController.text.trim().toUpperCase();
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ Pallet ID');
      return;
    }

    setState(() {
      _loadingPallet = true;
      _pallet = null;
    });

    final result = await _api.scanPalletForPutaway(
      palletId,
      stationId: widget.station.id,
    );
    setState(() => _loadingPallet = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    final pallet = result.data!;

    if (widget.station.allowedType != null &&
        pallet.type != widget.station.allowedType) {
      showErrorDialog(
        context,
        message:
            '${widget.station.id} รับเฉพาะ Pallet ประเภท '
            '${widget.station.allowedType}\n'
            'Pallet นี้เป็นประเภท ${pallet.type}',
      );
      return;
    }

    setState(() {
      _pallet = pallet;
      _selectedDestination =
          widget.station.fixedDestination ?? pallet.suggestedDestination;
    });
  }

  Future<void> _confirmPutaway() async {
    if (_pallet == null) return;

    final dest = _effectiveDestination;
    final destLabel = switch (dest) {
      'ASRS' => 'ASRS',
      'REPLENISH' => 'Replenish Station',
      _ => 'Prework',
    };
    final isSendStation = widget.station.fixedDestination != null;

    String title;
    String message;
    if (isSendStation) {
      title = 'ยืนยันส่ง Pallet ไป ASRS';
      final wrappingNote = _wrappingRequired
          ? '\nผ่าน Wrapping Machine ก่อน'
          : '';
      message =
          'ส่ง ${_pallet!.palletId} ไปเก็บที่ ASRS$wrappingNote\n\n'
          '${_wrappingRequired ? 'จะส่งเข้า Wrapping Machine ก่อน' : 'AMR จะมารับทันที'}';
    } else if (dest == 'REPLENISH') {
      title = 'ยืนยัน Replenish';
      message =
          'ส่ง Pallet ${_pallet!.palletId}\n'
          'ที่ ${widget.station.id} -> $destLabel\n\n'
          'AMR จะรับ Pallet ไปเติมสต็อก Rack';
    } else {
      title = 'ยืนยัน Putaway';
      final wrappingNote = _wrappingRequired
          ? '\nผ่าน Wrapping Machine ก่อน'
          : '';
      message =
          'เก็บ Pallet ${_pallet!.palletId}\n'
          'ที่ ${widget.station.id} -> $destLabel$wrappingNote\n\n'
          '${_wrappingRequired ? 'จะส่งเข้า Wrapping Machine ก่อน' : 'AMR จะมารับทันที'}';
    }

    final confirm = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'ยืนยัน',
    );
    if (!confirm) return;

    setState(() => _loadingConfirm = true);

    final result = await _api.confirmPutaway(
      stationId: widget.station.id,
      palletId: _pallet!.palletId,
      destination: dest,
      operatorId: widget.userId,
      wrappingRequired: _wrappingRequired,
    );

    setState(() => _loadingConfirm = false);

    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.viewPadding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: LoadingOverlay(
        loading: _loadingConfirm,
        message: 'กำลังสั่ง Putaway...',
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Station Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.station.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(widget.station.icon, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.station.id,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.station.label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      MdiIcons.robotIndustrialOutline,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'AMR Ready',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Scan Pallet
              Text(
                _isReceive ? 'เรียก Pallet จาก ASRS' : 'สแกน Pallet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isReceive) ...[
                const SizedBox(height: 4),
                Text(
                  'ใส่ Pallet ID (PW) ที่ต้องการเรียกจาก ASRS',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ScanTextField(
                label: 'Pallet ID',
                hint: 'เช่น PAL-001',
                controller: _palletController,
                onSubmit: _scanPallet,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _isReceive ? 'เรียก Pallet' : 'ค้นหา Pallet',
                icon: _isReceive ? MdiIcons.trayArrowDown : Icons.search,
                loading: _isReceive ? _loadingConfirm : _loadingPallet,
                onPressed: _scanPallet,
              ),

              // Pallet Info
              if (!_isReceive && _pallet != null) ...[
                const SizedBox(height: 16),
                StationPalletInfoCard(
                  pallet: _pallet!,
                  hasFixedDestination: widget.station.fixedDestination != null,
                  onViewItems: () => _showItemsDetail(context),
                ),

                if (widget.station.fixedDestination == null) ...[
                  const SizedBox(height: 16),
                  StationDestinationSelector(
                    palletType: _pallet!.type,
                    selectedDestination: _selectedDestination,
                    wrappingRequired: _wrappingRequired,
                    onDestinationChanged: (destination) {
                      setState(() {
                        _selectedDestination = destination;
                        if (destination != 'ASRS') {
                          _wrappingRequired = false;
                        }
                      });
                    },
                    onWrappingChanged: (value) {
                      setState(() => _wrappingRequired = value);
                    },
                  ),
                ],

                if (widget.station.fixedDestination == 'ASRS') ...[
                  const SizedBox(height: 12),
                  StationWrappingToggle(
                    value: _wrappingRequired,
                    onChanged: (value) {
                      setState(() => _wrappingRequired = value);
                    },
                  ),
                ],

                const SizedBox(height: 16),
                PrimaryButton(
                  label: widget.station.fixedDestination != null
                      ? 'ส่ง Pallet ไป ASRS'
                      : 'เก็บ Pallet',
                  icon: widget.station.fixedDestination != null
                      ? MdiIcons.warehouse
                      : MdiIcons.packageVariantClosed,
                  onPressed: _confirmPutaway,
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemsDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PalletItemsPage(
          palletId: _pallet!.palletId,
          type: _pallet!.type,
          items: _pallet!.items,
        ),
      ),
    );
  }
}
