import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../services/api_service.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../models/station_info.dart';
import 'dest_button.dart';
import 'pallet_items_page.dart';

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
      showErrorDialog(context, message: 'เธเธฃเธธเธ“เธฒเนเธชเน Pallet ID');
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
            '${widget.station.id} เธฃเธฑเธเน€เธเธเธฒเธฐ Pallet เธเธฃเธฐเน€เธ เธ— '
            '${widget.station.allowedType}\n'
            'Pallet เธเธตเนเน€เธเนเธเธเธฃเธฐเน€เธ เธ— ${pallet.type}',
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
      title = 'เธขเธทเธเธขเธฑเธเธชเนเธ Pallet เนเธ ASRS';
      final wrappingNote = _wrappingRequired
          ? '\nเธเนเธฒเธ Wrapping Machine เธเนเธญเธ'
          : '';
      message =
          'เธชเนเธ ${_pallet!.palletId} เนเธเน€เธเนเธเธ—เธตเน ASRS$wrappingNote\n\n'
          '${_wrappingRequired ? 'เธเธฐเธชเนเธเน€เธเนเธฒ Wrapping Machine เธเนเธญเธ' : 'AMR เธเธฐเธกเธฒเธฃเธฑเธเธ—เธฑเธเธ—เธต'}';
    } else if (dest == 'REPLENISH') {
      title = 'เธขเธทเธเธขเธฑเธ Replenish';
      message =
          'เธชเนเธ Pallet ${_pallet!.palletId}\n'
          'เธ—เธตเน ${widget.station.id} โ’ $destLabel\n\n'
          'AMR เธเธฐเธฃเธฑเธ Pallet เนเธเน€เธ•เธดเธกเธชเธ•เนเธญเธ Rack';
    } else {
      title = 'เธขเธทเธเธขเธฑเธ Putaway';
      final wrappingNote = _wrappingRequired
          ? '\nเธเนเธฒเธ Wrapping Machine เธเนเธญเธ'
          : '';
      message =
          'เน€เธเนเธ Pallet ${_pallet!.palletId}\n'
          'เธ—เธตเน ${widget.station.id} โ’ $destLabel$wrappingNote\n\n'
          '${_wrappingRequired ? 'เธเธฐเธชเนเธเน€เธเนเธฒ Wrapping Machine เธเนเธญเธ' : 'AMR เธเธฐเธกเธฒเธฃเธฑเธเธ—เธฑเธเธ—เธต'}';
    }

    final confirm = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'เธขเธทเธเธขเธฑเธ',
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
        message: 'เธเธณเธฅเธฑเธเธชเธฑเนเธ Putaway...',
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
                _isReceive ? 'เน€เธฃเธตเธขเธ Pallet เธเธฒเธ ASRS' : 'เธชเนเธเธ Pallet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isReceive) ...[
                const SizedBox(height: 4),
                Text(
                  'เนเธชเน Pallet ID (PW) เธ—เธตเนเธ•เนเธญเธเธเธฒเธฃเน€เธฃเธตเธขเธเธเธฒเธ ASRS',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ScanTextField(
                label: 'Pallet ID',
                hint: 'เน€เธเนเธ PAL-001',
                controller: _palletController,
                onSubmit: _scanPallet,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _isReceive ? 'เน€เธฃเธตเธขเธ Pallet' : 'เธเนเธเธซเธฒ Pallet',
                icon: _isReceive ? MdiIcons.trayArrowDown : Icons.search,
                loading: _isReceive ? _loadingConfirm : _loadingPallet,
                onPressed: _scanPallet,
              ),

              // Pallet Info
              if (!_isReceive && _pallet != null) ...[
                const SizedBox(height: 16),
                _buildPalletInfo(),

                if (widget.station.fixedDestination == null) ...[
                  const SizedBox(height: 16),
                  _buildDestinationSelector(),
                ],

                if (widget.station.fixedDestination == 'ASRS') ...[
                  const SizedBox(height: 12),
                  _buildWrappingToggle(),
                ],

                const SizedBox(height: 16),
                PrimaryButton(
                  label: widget.station.fixedDestination != null
                      ? 'เธชเนเธ Pallet เนเธ ASRS'
                      : 'เน€เธเนเธ Pallet',
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

  Widget _buildPalletInfo() {
    final isFG = _pallet!.type == 'FG';
    final typeColor = isFG ? AppTheme.success : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _pallet!.palletId,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _pallet!.type,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(label: 'เธชเธ–เธฒเธเธฐ', value: _pallet!.status),
          InfoRow(
            label: 'เธเธฅเธฒเธขเธ—เธฒเธ',
            value: widget.station.fixedDestination != null
                ? 'ASRS (convert PWโ’FG)'
                : 'เน€เธฅเธทเธญเธเธ”เนเธฒเธเธฅเนเธฒเธ',
          ),
          InfoRow(label: 'เธชเธดเธเธเนเธฒ', value: '${_pallet!.items.length} เธฃเธฒเธขเธเธฒเธฃ'),
          if (_pallet!.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _pallet!.message,
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showItemsDetail(context),
              icon: Icon(MdiIcons.eyeOutline, size: 18),
              label: Text('เธ”เธนเธชเธดเธเธเนเธฒเนเธ Pallet (${_pallet!.items.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
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

  Widget _buildDestinationSelector() {
    final isPW = _pallet!.type == 'PW';
    final headerColor = isPW ? AppTheme.warning : AppTheme.primary;
    final headerIcon = isPW ? Icons.warning_amber : MdiIcons.packageVariantClosed;
    final headerText = isPW
        ? 'Pallet เธเธฃเธฐเน€เธ เธ— PW โ€” เน€เธฅเธทเธญเธเธเธฅเธฒเธขเธ—เธฒเธ'
        : 'Pallet เธเธฃเธฐเน€เธ เธ— FG โ€” เน€เธฅเธทเธญเธเธเธฅเธฒเธขเธ—เธฒเธ';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, color: headerColor, size: 18),
              const SizedBox(width: 6),
              Text(
                headerText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DestButton(
                  label: 'ASRS',
                  subtitle: 'เน€เธเนเธเน€เธเนเธฒเธเธฅเธฑเธเธซเธฅเธฑเธ',
                  icon: MdiIcons.officeBuildingOutline,
                  selected: _selectedDestination == 'ASRS',
                  onTap: () => setState(() => _selectedDestination = 'ASRS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isPW
                    ? DestButton(
                        label: 'Prework',
                        subtitle: 'เธชเนเธเธเธธเธ” Prework',
                        icon: MdiIcons.cogOutline,
                        selected: _selectedDestination == 'PREWORK',
                        onTap: () => setState(() {
                          _selectedDestination = 'PREWORK';
                          _wrappingRequired = false;
                        }),
                      )
                    : DestButton(
                        label: 'Replenish',
                        subtitle: 'เน€เธ•เธดเธกเธชเธ•เนเธญเธ Rack',
                        icon: Icons.refresh,
                        selected: _selectedDestination == 'REPLENISH',
                        onTap: () => setState(() {
                          _selectedDestination = 'REPLENISH';
                          _wrappingRequired = false;
                        }),
                      ),
              ),
            ],
          ),
          if (_selectedDestination == 'ASRS') ...[
            const SizedBox(height: 12),
            _buildWrappingToggle(),
          ],
        ],
      ),
    );
  }

  Widget _buildWrappingToggle() {
    return GestureDetector(
      onTap: () => setState(() => _wrappingRequired = !_wrappingRequired),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _wrappingRequired
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _wrappingRequired
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              MdiIcons.textBoxOutline,
              color: _wrappingRequired ? AppTheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เธเธฑเธเธชเธดเธเธเนเธฒ (Wrapping Machine)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _wrappingRequired
                          ? AppTheme.primary
                          : AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    'เธเธฑเธ Pallet เธเนเธญเธเธเธณเน€เธเนเธฒ ASRS',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey(context),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _wrappingRequired,
              onChanged: (v) => setState(() => _wrappingRequired = v),
              activeThumbColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
