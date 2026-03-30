// lib/screens/putaway/putaway_widgets.dart
// Shared components สำหรับ PutawayScreen และ PutawayPreworkScreen

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import '../../models/wms_models.dart';

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

  const StationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.isDispatching = false,
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
      onTap: widget.isDispatching ? null : widget.onTap,
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white70, size: 28),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: Colors.white, size: 11),
              SizedBox(width: 3),
              Text(
                'กดเลือก',
                style: TextStyle(color: Colors.white, fontSize: 10),
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

    if (_isReceive) {
      await _recallPallet(palletId);
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

  Future<void> _recallPallet(String palletId) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'เรียก Pallet จาก ASRS',
      message:
          'เรียก $palletId จาก ASRS\n'
          'มาที่ ${widget.station.id}\n\n'
          'AMR จะนำ Pallet มาส่งทันที',
      confirmLabel: 'เรียก Pallet',
    );
    if (!confirm || !mounted) return;

    setState(() => _loadingConfirm = true);

    final result = await _api.recallToPrework(
      palletId: palletId,
      stationId: widget.station.id,
      operatorId: widget.userId,
    );

    setState(() => _loadingConfirm = false);
    if (!mounted) return;

    if (!result.success) {
      showErrorDialog(context, message: result.error!);
      return;
    }

    Navigator.pop(context);
    widget.onConfirmed();
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
        ],
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
