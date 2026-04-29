import 'package:flutter/material.dart';

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
    final stationLabel = _formatSortingStationId(s.stationId);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.toggle_off,
                color: Color.fromRGBO(46, 125, 50, 1),
              ),
              title: const Text('ปิดใช้งาน Station'),
              subtitle: Text(stationLabel),
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
    final stationLabel = _formatSortingStationId(s.stationId);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.toggle_on,
                color: Color.fromRGBO(0, 0, 0, 1),
              ),
              title: const Text('เปิดใช้งาน Station'),
              subtitle: Text(
                '$stationLabel${s.disableReason != null ? "  ·  เหตุผลปิด: ${s.disableReason}" : ""}',
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

  Future<void> _confirmToggle(
    SortingStationView s, {
    required bool enable,
  }) async {
    final stationLabel = _formatSortingStationId(s.stationId);
    final confirm = await showConfirmDialog(
      context,
      title: enable ? 'เปิดใช้งาน Station' : 'ปิดใช้งาน Station',
      message:
          '$stationLabel จะ ${enable ? "พร้อมรับ batch" : "หยุดรับ batch ใหม่"}',
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
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sort, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ภาพรวมสถานี Sorting',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    'ว่าง',
                    free,
                    AppTheme.success,
                    Icons.inbox_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statTile(
                    'กำลังใช้',
                    busy,
                    AppTheme.warning,
                    Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statTile('ปิด', disabled, Colors.grey, Icons.block),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, int n, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              '$n',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
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
        childAspectRatio: 1.08,
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
    final stationLabel = _formatSortingStationId(s.stationId);

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
        : isBusy
        ? accent.withValues(alpha: 0.09)
        : accent.withValues(alpha: 0.07);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withValues(alpha: isDisabled ? 0.22 : 0.58),
            width: isBusy || isFull ? 1.6 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.grey.withValues(alpha: 0.12)
                        : accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pallet,
                    size: 22,
                    color: isDisabled ? Colors.grey : accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDisabled ? Colors.grey[500] : null,
                    ),
                  ),
                ),
                _statusPill(s.status, accent),
              ],
            ),
            const SizedBox(height: 10),
            if (isBusy && s.cartonsCount != null && s.maxCapacity != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        s.palletId == null
                            ? 'กำลังรับ batch'
                            : _formatSortingPalletId(s.palletId!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[700],
                          fontFamily: s.palletId != null ? 'monospace' : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${s.cartonsCount}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  Text(
                    '/${s.maxCapacity}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'กล่อง',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
              const Spacer(),
              Icon(Icons.power_settings_new, color: Colors.grey[400], size: 28),
              const SizedBox(height: 8),
              Text(
                'ปิดใช้งาน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[600],
                ),
              ),
              if (s.disableReason != null)
                Text(
                  s.disableReason!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ] else ...[
              const Spacer(),
              const Icon(
                Icons.move_to_inbox,
                size: 30,
                color: AppTheme.success,
              ),
              const SizedBox(height: 8),
              const Text(
                'ว่าง',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'รอ batch เข้า',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textGrey(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status, Color color) {
    final label = switch (status) {
      'BUSY' => 'ใช้งาน',
      'DISABLED' => 'ปิด',
      _ => 'ว่าง',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
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
    final stationLabel = _formatSortingStationId(widget.stationId);
    final confirm = await showConfirmDialog(
      context,
      title: 'Clear Station',
      message:
          'ส่ง ${_formatSortingPalletId(_detail!.palletId!)} ออกจาก $stationLabel\nstation จะกลับมาว่าง',
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: _loading || _detail == null
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(scroll),
      ),
    );
  }

  Widget _buildContent(ScrollController scroll) {
    final d = _detail!;
    final stationLabel = _formatSortingStationId(d.stationId);
    final pct = d.maxCapacity > 0 ? d.cartonsCount / d.maxCapacity : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pallet,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stationLabel,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (d.isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FULL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (d.palletId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatSortingPalletId(d.palletId!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[700],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${d.cartonsCount}',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: pct >= 1.0
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${d.maxCapacity} กล่อง',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (d.pendingCount > 0)
                    Text(
                      '+ ${d.pendingCount} กำลังเข้า…',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(
                    pct >= 1.0 ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: d.cartons.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = d.cartons[i];
              final kg = (c.weightGram / 1000).toStringAsFixed(2);
              return ListTile(
                minVerticalPadding: 10,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.success.withValues(alpha: 0.15),
                  child: Text(
                    '${c.sequenceNo}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.success,
                    ),
                  ),
                ),
                title: Text(
                  c.packingId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  '${c.owner}  ·  $kg kg  ·  ${c.itemCount} ชิ้น',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Text(
                  _formatTime(c.sortedAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                  ),
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
                  label: const Text(
                    'Clear Station',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

String _formatSortingStationId(int stationId) =>
    'STN-${stationId.toString().padLeft(2, '0')}';

String _formatSortingPalletId(String palletId) => 'Pallet $palletId';
