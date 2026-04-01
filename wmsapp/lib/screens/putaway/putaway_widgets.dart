// lib/screens/putaway/putaway_widgets.dart
// Shared components สำหรับ PutawayScreen และ PutawayPreworkScreen

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';
import '../../widgets/part_thumbnail.dart';

// ── Station definition ───────────────────────
enum PWRole { none, receive, send }

class StationInfo {
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  final String? allowedType;
  final String? fixedDestination;
  final PWRole pwRole;

  const StationInfo({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
    this.allowedType,
    this.fixedDestination,
    this.pwRole = PWRole.none,
  });
}

// =============================================
// StationCard  (StatefulWidget — มี animation)
// =============================================
class StationCard extends StatefulWidget {
  final StationInfo station;
  final VoidCallback onTap;
  final bool isDispatching;
  final String? busyPalletId;
  final String? busyDestination;

  const StationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.isDispatching = false,
    this.busyPalletId,
    this.busyDestination,
  });

  @override
  State<StationCard> createState() => _StationCardState();
}

class _StationCardState extends State<StationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isDispatching) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(StationCard old) {
    super.didUpdateWidget(old);
    if (widget.isDispatching && !old.isDispatching) {
      _ctrl.repeat();
    } else if (!widget.isDispatching && old.isDispatching) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: widget.isDispatching ? AppTheme.danger : widget.station.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (widget.isDispatching
                          ? AppTheme.danger
                          : widget.station.color)
                      .withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.isDispatching
            ? _buildDispatchingContent()
            : _buildNormalContent(),
      ),
    );
  }

  Widget _buildDispatchingContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white70, size: 22),
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _arrow(phase: 0.0),
                const SizedBox(width: 2),
                _arrow(phase: 0.33),
                const SizedBox(width: 2),
                _arrow(phase: 0.66),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          widget.station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          widget.station.pwRole == PWRole.receive
              ? 'AMR กำลังนำ Pallet มา...'
              : 'AMR กำลังมารับ...',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (widget.busyPalletId != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  widget.busyPalletId!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.busyDestination != null)
                  Text(
                    '→ ${widget.busyDestination}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _arrow({required double phase}) {
    double t = (_ctrl.value - phase) % 1.0;
    double opacity = t < 0.5 ? t * 2 : (1.0 - t) * 2;
    opacity = opacity.clamp(0.15, 1.0);
    return Opacity(
      opacity: opacity,
      child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 22),
    );
  }

  Widget _buildNormalContent() {
    final hasBusy = widget.busyPalletId != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.station.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_agvWheel(), const SizedBox(width: 8), _agvWheel()],
        ),
        const SizedBox(height: 8),
        Text(
          widget.station.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          widget.station.label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        if (hasBusy) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  widget.busyPalletId!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.busyDestination != null)
                  Text(
                    widget.busyDestination!,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasBusy ? Icons.info_outline : Icons.touch_app,
                color: Colors.white,
                size: 11,
              ),
              const SizedBox(width: 3),
              Text(
                hasBusy ? 'กดดูรายละเอียด' : 'กดเลือก',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _agvWheel() => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}

// =============================================
// StationSheet  (bottom sheet popup)
// =============================================
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

  Future<void> _confirmPutaway({bool convertToFG = true}) async {
    if (_pallet == null) return;

    final dest = _effectiveDestination;
    final destLabel = switch (dest) {
      'ASRS' => 'ASRS',
      'REPLENISH' => 'Replenish Station',
      _ => 'Prework',
    };
    final isConvert = widget.station.fixedDestination != null && convertToFG;
    final isSendAsrsAsPW =
        widget.station.fixedDestination != null && !convertToFG;

    String title;
    String message;
    if (isConvert) {
      title = 'ยืนยัน Convert & Putaway';
      final wrappingNote = _wrappingRequired
          ? '\nผ่าน Wrapping Machine ก่อน'
          : '';
      message =
          'เปลี่ยน ${_pallet!.palletId} (PW → FG)\n'
          'แล้วส่งเข้า ASRS$wrappingNote\n\n'
          '${_wrappingRequired ? 'จะส่งเข้า Wrapping Machine ก่อน' : 'AMR จะมารับทันที'}';
    } else if (isSendAsrsAsPW) {
      title = 'ยืนยันส่งไป ASRS (ยังเป็น PW)';
      final wrappingNote = _wrappingRequired
          ? '\nผ่าน Wrapping Machine ก่อน'
          : '';
      message =
          'ส่ง ${_pallet!.palletId} ไปเก็บที่ ASRS\n'
          'โดยยังคงสถานะเป็น PW (ไม่ convert)$wrappingNote\n\n'
          '${_wrappingRequired ? 'จะส่งเข้า Wrapping Machine ก่อน' : 'AMR จะมารับทันที'}';
    } else if (dest == 'REPLENISH') {
      title = 'ยืนยัน Replenish';
      message =
          'ส่ง Pallet ${_pallet!.palletId}\n'
          'ที่ ${widget.station.id} → $destLabel\n\n'
          'AMR จะรับ Pallet ไปเติมสต็อก Rack';
    } else {
      title = 'ยืนยัน Putaway';
      final wrappingNote = _wrappingRequired
          ? '\nผ่าน Wrapping Machine ก่อน'
          : '';
      message =
          'เก็บ Pallet ${_pallet!.palletId}\n'
          'ที่ ${widget.station.id} → $destLabel$wrappingNote\n\n'
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
      convertToFG: convertToFG,
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
                    const Icon(
                      Icons.smart_toy,
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
                icon: _isReceive ? Icons.download : Icons.search,
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
                      ? 'ติดสติ๊กเกอร์ ส่ง ASRS'
                      : 'เก็บ Pallet',
                  icon: widget.station.fixedDestination != null
                      ? Icons.swap_horiz
                      : Icons.inventory_2,
                  onPressed: _confirmPutaway,
                ),

                if (widget.station.fixedDestination != null) ...[
                  const SizedBox(height: 10),
                  WarningButton(
                    label: 'ส่งไป ASRS (ยังเป็น PW)',
                    icon: Icons.warehouse,
                    onPressed: () => _confirmPutaway(convertToFG: false),
                  ),
                ],
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
          InfoRow(label: 'สถานะ', value: _pallet!.status),
          InfoRow(
            label: 'ปลายทาง',
            value: widget.station.fixedDestination != null
                ? 'ASRS (convert PW→FG)'
                : 'เลือกด้านล่าง',
          ),
          InfoRow(label: 'สินค้า', value: '${_pallet!.items.length} รายการ'),
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
              icon: const Icon(Icons.visibility, size: 18),
              label: Text('ดูสินค้าใน Pallet (${_pallet!.items.length})'),
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
    final headerIcon = isPW ? Icons.warning_amber : Icons.inventory_2;
    final headerText = isPW
        ? 'Pallet ประเภท PW — เลือกปลายทาง'
        : 'Pallet ประเภท FG — เลือกปลายทาง';

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
                  subtitle: 'เก็บเข้าคลังหลัก',
                  icon: Icons.domain,
                  selected: _selectedDestination == 'ASRS',
                  onTap: () => setState(() => _selectedDestination = 'ASRS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isPW
                    ? DestButton(
                        label: 'Prework',
                        subtitle: 'ส่งจุด Prework',
                        icon: Icons.build_circle,
                        selected: _selectedDestination == 'PREWORK',
                        onTap: () => setState(() {
                          _selectedDestination = 'PREWORK';
                          _wrappingRequired = false;
                        }),
                      )
                    : DestButton(
                        label: 'Replenish',
                        subtitle: 'เติมสต็อก Rack',
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
              Icons.wrap_text,
              color: _wrappingRequired ? AppTheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'พันสินค้า (Wrapping Machine)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _wrappingRequired
                          ? AppTheme.primary
                          : AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    'พัน Pallet ก่อนนำเข้า ASRS',
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

// =============================================
// DestButton — destination choice button
// =============================================
class DestButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const DestButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppTheme.textGrey(context),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: selected ? Colors.white70 : AppTheme.textGrey(context),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// PalletItemsPage — หน้าแสดงสินค้าใน Pallet
// =============================================
class PalletItemsPage extends StatelessWidget {
  final String palletId;
  final String type;
  final List<UnloadItem> items;

  const PalletItemsPage({
    super.key,
    required this.palletId,
    required this.type,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isFG = type == 'FG';
    final typeColor = isFG ? AppTheme.success : AppTheme.warning;

    return Scaffold(
      appBar: WmsAppBar(title: '$palletId — สินค้า'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: typeColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          palletId,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          'ประเภท $type · ${items.length} รายการ · รวม ${items.fold<int>(0, (sum, i) => sum + i.qty)} ชิ้น',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Items list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        PartThumbnail(imageUrl: item.imageUrl, size: 56),
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
                              const SizedBox(height: 2),
                              Text(
                                item.itemDesc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textGrey(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${item.owner} / ${item.brand}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textGrey(context),
                                    ),
                                  ),
                                  if (item.lotNumber != null &&
                                      item.lotNumber!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.label_outline,
                                      size: 12,
                                      color: AppTheme.textGrey(context),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.lotNumber!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textGrey(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Text(
                              '${item.qty}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              'ชิ้น',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textGrey(context),
                              ),
                            ),
                          ],
                        ),
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
  }
}

// =============================================
// PreworkReceivePage — รับ Pallet ที่ Prework Station
// เลือก Pallet (Status=PREWORK) → ตัดยอด → แสดง items → คืน pallet เปล่า
// =============================================
class PreworkReceivePage extends StatefulWidget {
  final StationInfo station;
  final String userId;
  final VoidCallback onCompleted;

  const PreworkReceivePage({
    super.key,
    required this.station,
    required this.userId,
    required this.onCompleted,
  });

  @override
  State<PreworkReceivePage> createState() => _PreworkReceivePageState();
}

enum _PageState { loading, selectPallet, received, error }

class _PreworkReceivePageState extends State<PreworkReceivePage> {
  final _api = ApiService();

  _PageState _state = _PageState.loading;
  bool _actionLoading = false;

  // เลือก pallet
  List<Map<String, dynamic>> _preworkPallets = [];

  // หลังตัดยอด
  String? _selectedPalletId;
  List<UnloadItem> _receivedItems = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreworkPallets();
  }

  Future<void> _loadPreworkPallets() async {
    setState(() => _state = _PageState.loading);

    final result = await _api.getPreworkPallets();
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _state = _PageState.error;
        _error = result.error;
      });
      return;
    }

    setState(() {
      _preworkPallets = result.data!;
      _state = _PageState.selectPallet;
    });
  }

  Future<void> _receivePallet(Map<String, dynamic> pallet) async {
    final palletId = pallet['palletId'] as String;
    final itemCount = pallet['itemCount'] as int;
    final totalQty = pallet['totalQty'] as int;

    final confirm = await showConfirmDialog(
      context,
      title: 'รับ Pallet $palletId',
      message:
          'แมพ $palletId เข้า ${widget.station.id}\n'
          'สินค้า $itemCount รายการ ($totalQty ชิ้น)\n\n'
          'ตัดยอดออกจาก Pallet ทันที?',
      confirmLabel: 'รับ & ตัดยอด',
    );
    if (!confirm || !mounted) return;

    setState(() => _actionLoading = true);

    final result = await _api.preworkReceive(
      palletId: palletId,
      stationId: widget.station.id,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    setState(() {
      _selectedPalletId = palletId;
      _receivedItems = result.data!.items;
      _state = _PageState.received;
    });
  }

  Future<void> _returnPallet() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'คืน Pallet เปล่า',
      message:
          'คืน $_selectedPalletId\n'
          'Pallet จะถูกเปลี่ยนเป็นสถานะ AVAILABLE\n\n'
          'ยืนยันคืน Pallet?',
      confirmLabel: 'คืน Pallet',
    );
    if (!confirm || !mounted) return;

    setState(() => _actionLoading = true);

    final result = await _api.preworkReturnPallet(
      palletId: _selectedPalletId!,
      stationId: widget.station.id,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    showSuccessSnackbar(context, '$_selectedPalletId คืนแล้ว (AVAILABLE)');
    widget.onCompleted();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _actionLoading,
      message: _state == _PageState.received
          ? 'กำลังคืน Pallet...'
          : 'กำลังตัดยอด...',
      child: Scaffold(
        appBar: WmsAppBar(title: 'รับ Pallet — ${widget.station.id}'),
        body: SafeArea(
          top: false,
          child: switch (_state) {
            _PageState.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            _PageState.error => _buildError(),
            _PageState.selectPallet => _buildSelectPallet(),
            _PageState.received => _buildReceived(),
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 56),
            const SizedBox(height: 16),
            Text(
              _error ?? 'เกิดข้อผิดพลาด',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'ลองใหม่',
              icon: Icons.refresh,
              onPressed: _loadPreworkPallets,
            ),
          ],
        ),
      ),
    );
  }

  // ── หน้าเลือก Pallet ──────────────────────
  Widget _buildSelectPallet() {
    if (_preworkPallets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'ไม่มี Pallet ที่รอ Prework',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGrey(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ส่ง Pallet PW มาจาก Putaway for Receive ก่อน',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textGrey(context),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'รีเฟรช',
                icon: Icons.refresh,
                onPressed: _loadPreworkPallets,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2,
                size: 18,
                color: AppTheme.textPrimary(context),
              ),
              const SizedBox(width: 6),
              Text(
                'เลือก Pallet ที่จะรับ (${_preworkPallets.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadPreworkPallets,
                tooltip: 'รีเฟรช',
              ),
            ],
          ),
        ),

        // Pallet list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _preworkPallets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = _preworkPallets[index];
              final palletId = p['palletId'] as String;
              final type = p['type'] as String? ?? '-';
              final itemCount = p['itemCount'] as int;
              final totalQty = p['totalQty'] as int;
              final items = p['items'] as List? ?? [];

              return GestureDetector(
                onTap: () => _receivePallet(p),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pallet header
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: AppTheme.warning,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            palletId,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$itemCount รายการ · $totalQty ชิ้น',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textGrey(context),
                            ),
                          ),
                        ],
                      ),
                      // Items preview
                      if (items.isNotEmpty) ...[
                        const Divider(height: 16),
                        for (final item in items.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                PartThumbnail(
                                  imageUrl: item['imageUrl'] as String?,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item['partId']} — ${item['itemDesc']}',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'x${item['qty']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (items.length > 3)
                          Text(
                            '... อีก ${items.length - 3} รายการ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textGrey(context),
                            ),
                          ),
                      ],
                      // Tap hint
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'กดเพื่อรับ & ตัดยอด',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
    );
  }

  // ── หลังตัดยอดแล้ว ─────────────────────────
  Widget _buildReceived() {
    final totalQty = _receivedItems.fold<int>(0, (sum, i) => sum + i.qty);

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ตัดยอดจาก $_selectedPalletId แล้ว',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      '${_receivedItems.length} รายการ · รวม $totalQty ชิ้น',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Section label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2,
                size: 18,
                color: AppTheme.textPrimary(context),
              ),
              const SizedBox(width: 6),
              Text(
                'สินค้าที่ตัดยอด',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
        ),

        // Items table
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _receivedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _receivedItems[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    PartThumbnail(imageUrl: item.imageUrl, size: 52),
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
                          const SizedBox(height: 2),
                          Text(
                            item.itemDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textGrey(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${item.owner} / ${item.brand}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textGrey(context),
                                ),
                              ),
                              if (item.lotNumber != null &&
                                  item.lotNumber!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.label_outline,
                                  size: 12,
                                  color: AppTheme.textGrey(context),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  item.lotNumber!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textGrey(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Text(
                          '${item.qty}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          'ชิ้น',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Return pallet button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _returnPallet,
              icon: const Icon(Icons.replay, color: Colors.white),
              label: const Text(
                'คืน Pallet เปล่า',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
