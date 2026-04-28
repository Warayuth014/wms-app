import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../services/sorting_signalr_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

class SortingScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const SortingScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<SortingScreen> createState() => _SortingScreenState();
}

class _SortingScreenState extends State<SortingScreen> {
  final _api = ApiService();
  final _hub = SortingSignalRService();

  bool _loading = false;
  List<SortingStationView> _stations = [];

  @override
  void initState() {
    super.initState();
    _hub.onCounterUpdated(_onCounterUpdated);
    _hub.onStationFull(_onAnyStationEvent);
    _hub.onStationCleared(_onAnyStationEvent);
    _hub.onStationToggled(_onAnyStationEvent);
    _hub.onBatchAssigned(_onAnyStationEvent);
    _initSignalR();
    _loadStations();
  }

  @override
  void dispose() {
    _hub.offCounterUpdated(_onCounterUpdated);
    _hub.offStationFull(_onAnyStationEvent);
    _hub.offStationCleared(_onAnyStationEvent);
    _hub.offStationToggled(_onAnyStationEvent);
    _hub.offBatchAssigned(_onAnyStationEvent);
    _hub.disconnect();
    super.dispose();
  }

  Future<void> _initSignalR() async => _hub.connect();

  // ── SignalR handlers ───────────────────────────────────────
  void _onCounterUpdated(Map<String, dynamic> data) {
    final stationId = data['stationId'] as int?;
    if (stationId == null || !mounted) return;

    setState(() {
      final idx = _stations.indexWhere((s) => s.stationId == stationId);
      if (idx < 0) return;
      _stations[idx] = _stations[idx].copyWith(
        cartonsCount: data['current'] as int?,
        maxCapacity: data['total'] as int?,
        isFull: data['isFull'] as bool?,
        palletId: data['palletId'] as String?,
        status: 'BUSY',
      );
    });
  }

  void _onAnyStationEvent(Map<String, dynamic> _) {
    // เปลี่ยนสถานะ + อาจมี station ใหม่ assign → reload ทั้งกริด
    _loadStations();
  }

  // ── API ──────────────────────────────────────────────────
  Future<void> _loadStations() async {
    setState(() => _loading = true);
    final res = await _api.getSortingStations();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'โหลด stations ไม่สำเร็จ');
      return;
    }
    setState(() => _stations = res.data!);
  }

  Future<void> _openStation(SortingStationView s) async {
    if (s.status == 'DISABLED') {
      _showDisabledMenu(s);
      return;
    }
    if (s.status == 'AVAILABLE') {
      _showAvailableMenu(s);
      return;
    }
    // BUSY → open detail sheet
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StationDetailSheet(
        stationId: s.stationId,
        userId: widget.userId,
        onChanged: _loadStations,
      ),
    );
  }

  void _showAvailableMenu(SortingStationView s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.toggle_off_outlined),
              title: const Text('ปิดใช้งาน Station'),
              subtitle: Text('SP-${s.stationId.toString().padLeft(2, '0')}'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmToggle(s, enable: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDisabledMenu(SortingStationView s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.toggle_on, color: AppTheme.success),
              title: const Text('เปิดใช้งาน Station'),
              subtitle: Text(
                'SP-${s.stationId.toString().padLeft(2, '0')}'
                '${s.disableReason != null ? "  ·  เหตุผลปิด: ${s.disableReason}" : ""}',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmToggle(s, enable: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmToggle(SortingStationView s, {required bool enable}) async {
    final confirm = await showConfirmDialog(
      context,
      title: enable ? 'เปิดใช้งาน Station' : 'ปิดใช้งาน Station',
      message:
          'SP-${s.stationId.toString().padLeft(2, '0')} จะ ${enable ? "พร้อมรับ batch" : "หยุดรับ batch ใหม่"}',
      confirmLabel: enable ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
      isDanger: !enable,
    );
    if (!confirm) return;

    setState(() => _loading = true);
    final res = await _api.toggleSortingStation(
      stationId: s.stationId,
      enable: enable,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Toggle ไม่สำเร็จ');
      return;
    }
    _loadStations();
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Sorting Stations', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังโหลด...',
          child: RefreshIndicator(
            onRefresh: _loadStations,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final busy = _stations.where((s) => s.status == 'BUSY').length;
    final disabled = _stations.where((s) => s.status == 'DISABLED').length;
    final free = _stations.length - busy - disabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('ว่าง', free, AppTheme.success),
            _stat('กำลังใช้', busy, AppTheme.warning),
            _stat('ปิด', disabled, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int n, Color color) => Column(
        children: [
          Text('$n',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      );

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _stations.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, i) => _StationCard(
        station: _stations[i],
        onTap: () => _openStation(_stations[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Station card — 1 card per station
// ─────────────────────────────────────────────────────────────
class _StationCard extends StatelessWidget {
  final SortingStationView station;
  final VoidCallback onTap;

  const _StationCard({required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = station;
    final stationLabel = 'SP-${s.stationId.toString().padLeft(2, '0')}';

    final isDisabled = s.status == 'DISABLED';
    final isBusy = s.status == 'BUSY';
    final isFull = s.isFull == true;

    final accent = isDisabled
        ? Colors.grey
        : isFull
            ? AppTheme.success
            : isBusy
                ? AppTheme.warning
                : AppTheme.primary;

    final bg = isDisabled
        ? Colors.grey.withValues(alpha: 0.08)
        : accent.withValues(alpha: 0.06);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withValues(alpha: isDisabled ? 0.25 : 0.5),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pallet,
                    size: 18,
                    color: isDisabled ? Colors.grey : accent),
                const SizedBox(width: 6),
                Text(stationLabel,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDisabled ? Colors.grey : null)),
                const Spacer(),
                _statusPill(s.status, accent),
              ],
            ),
            const Spacer(),
            if (isBusy && s.cartonsCount != null && s.maxCapacity != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${s.cartonsCount}',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: accent)),
                  Text('/${s.maxCapacity}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
              if (s.palletId != null)
                Text(s.palletId!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (s.maxCapacity ?? 0) > 0
                      ? (s.cartonsCount ?? 0) / s.maxCapacity!
                      : 0,
                  minHeight: 5,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ] else if (isDisabled) ...[
              Text('ปิดใช้งาน',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600])),
              if (s.disableReason != null)
                Text(s.disableReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ] else ...[
              Text('ว่าง — รอ batch',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textGrey(context))),
              const SizedBox(height: 4),
              Icon(MdiIcons.gestureTap, size: 14, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status, Color color) {
    final label = switch (status) {
      'BUSY' => 'BUSY',
      'DISABLED' => 'OFF',
      _ => 'FREE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Station Detail Sheet — เห็น cartons + ปุ่ม Clear (ถ้า full)
// ─────────────────────────────────────────────────────────────
class _StationDetailSheet extends StatefulWidget {
  final int stationId;
  final String userId;
  final VoidCallback onChanged;

  const _StationDetailSheet({
    required this.stationId,
    required this.userId,
    required this.onChanged,
  });

  @override
  State<_StationDetailSheet> createState() => _StationDetailSheetState();
}

class _StationDetailSheetState extends State<_StationDetailSheet> {
  final _api = ApiService();
  final _hub = SortingSignalRService();
  bool _loading = false;
  SortingStationDetail? _detail;

  @override
  void initState() {
    super.initState();
    _hub.onCounterUpdated(_onLive);
    _hub.onStationFull(_onLive);
    _load();
  }

  @override
  void dispose() {
    _hub.offCounterUpdated(_onLive);
    _hub.offStationFull(_onLive);
    super.dispose();
  }

  void _onLive(Map<String, dynamic> data) {
    final sid = data['stationId'] as int?;
    if (sid == widget.stationId && mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getSortingStation(widget.stationId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.success) {
      setState(() => _detail = res.data);
    }
  }

  Future<void> _clear() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Clear Station',
      message:
          'ส่ง Pallet ${_detail!.palletId} ไป Docking Area\nstation จะกลับมาว่าง',
      confirmLabel: 'Clear',
    );
    if (!confirm) return;

    setState(() => _loading = true);
    final res = await _api.clearSortingStation(
      stationId: widget.stationId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.success) {
      showErrorDialog(context, message: res.error ?? 'Clear ไม่สำเร็จ');
      return;
    }
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loading || _detail == null
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(scroll),
      ),
    );
  }

  Widget _buildContent(ScrollController scroll) {
    final d = _detail!;
    final stationLabel = 'SP-${d.stationId.toString().padLeft(2, '0')}';
    final pct = d.maxCapacity > 0 ? d.cartonsCount / d.maxCapacity : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pallet, color: AppTheme.primary, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(stationLabel,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  if (d.isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FULL',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.success)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (d.palletId != null)
                Text(d.palletId!,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontFamily: 'monospace')),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${d.cartonsCount} / ${d.maxCapacity} cartons',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                  if (d.pendingCount > 0)
                    Text('+ ${d.pendingCount} กำลังเข้า…',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(
                      pct >= 1.0 ? AppTheme.success : AppTheme.warning),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: d.cartons.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = d.cartons[i];
              final kg = (c.weightGram / 1000).toStringAsFixed(2);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.success.withValues(alpha: 0.15),
                  child: Text('${c.sequenceNo}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.success)),
                ),
                title: Text(c.packingId,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text(
                  '${c.owner}  ·  $kg kg  ·  ${c.itemCount} ชิ้น',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                trailing: Text(
                  _formatTime(c.sortedAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              );
            },
          ),
        ),
        if (d.isFull)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.cleaning_services, size: 20),
                  label: const Text('Clear Station',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}:'
        '${l.second.toString().padLeft(2, '0')}';
  }
}
