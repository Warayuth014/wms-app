// lib/screens/sorting/sorting_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../models/wms_models.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import 'widgets/sorting_setup_card.dart';
import 'widgets/sorting_session_header.dart';
import 'widgets/sorting_carton_scan_card.dart';
import 'widgets/sorting_items_list.dart';

enum _SortState { setup, scanning, done }

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
  final _palletCtrl = TextEditingController();
  final _palletFocus = FocusNode();
  final _cartonCtrl = TextEditingController();
  final _cartonFocus = FocusNode();

  _SortState _state = _SortState.setup;
  bool _loading = false;

  List<SortStation> _stations = [];
  String? _selectedStationId;
  SortSession? _session;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _palletCtrl.dispose();
    _palletFocus.dispose();
    _cartonCtrl.dispose();
    _cartonFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    final result = await _api.getSortStations();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลด Station ไม่ได้');
      return;
    }

    setState(() {
      _stations = result.data!;
      _selectedStationId ??= _stations
          .firstWhere(
            (s) => s.status == 'AVAILABLE',
            orElse: () => _stations.isNotEmpty
                ? _stations.first
                : SortStation(
                    stationId: '',
                    name: '',
                    status: 'AVAILABLE',
                  ),
          )
          .stationId;
      if (_selectedStationId!.isEmpty) _selectedStationId = null;
    });
  }

  Future<void> _openSession() async {
    final palletId = _palletCtrl.text.trim().toUpperCase();
    if (_selectedStationId == null || _selectedStationId!.isEmpty) {
      showErrorDialog(context, message: 'กรุณาเลือก Station');
      return;
    }
    if (palletId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาสแกน Pallet');
      return;
    }

    setState(() => _loading = true);
    final result = await _api.openSortSession(
      stationId: _selectedStationId!,
      sortPalletId: palletId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เปิด Session ไม่ได้');
      return;
    }

    setState(() {
      _session = result.data;
      _state = _SortState.scanning;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cartonFocus.requestFocus();
    });
  }

  Future<void> _scanCarton() async {
    if (_session == null) return;
    final cartonId = _cartonCtrl.text.trim().toUpperCase();
    if (cartonId.isEmpty) return;

    setState(() => _loading = true);
    final result = await _api.scanSortCarton(
      sessionId: _session!.sessionId,
      cartonId: cartonId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'สแกน Carton ไม่สำเร็จ');
      _cartonCtrl.clear();
      _cartonFocus.requestFocus();
      return;
    }

    setState(() => _session = result.data);
    showSuccessSnackbar(context, 'สแกน $cartonId แล้ว');
    _cartonCtrl.clear();
    _cartonFocus.requestFocus();
  }

  Future<void> _closeSession() async {
    if (_session == null) return;
    final confirm = await showConfirmDialog(
      context,
      title: 'ปิด Session',
      message:
          'ปิด Session และส่ง Pallet ${_session!.sortPalletId} ไป Docking?',
      confirmLabel: 'ปิด',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);
    final result = await _api.closeSortSession(
      sessionId: _session!.sessionId,
      operatorId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'ปิด Session ไม่ได้');
      return;
    }

    setState(() {
      _session = result.data;
      _state = _SortState.done;
    });
  }

  void _resetForNext() {
    setState(() {
      _session = null;
      _palletCtrl.clear();
      _cartonCtrl.clear();
      _state = _SortState.setup;
    });
    _loadStations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Sorting', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: LoadingOverlay(
          loading: _loading,
          message: 'กำลังประมวลผล...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_state == _SortState.setup) _buildSetup(),
                if (_state == _SortState.scanning) _buildScanning(),
                if (_state == _SortState.done) _buildDone(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    return SortingSetupCard(
      stations: _stations,
      selectedStationId: _selectedStationId,
      onStationChanged: (id) => setState(() => _selectedStationId = id),
      palletController: _palletCtrl,
      palletFocus: _palletFocus,
      onOpen: _openSession,
    );
  }

  Widget _buildScanning() {
    final session = _session!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SortingSessionHeader(session: session),
        const SizedBox(height: 12),
        SortingCartonScanCard(
          controller: _cartonCtrl,
          focusNode: _cartonFocus,
          onScan: _scanCarton,
        ),
        const SizedBox(height: 12),
        SortingItemsList(items: session.items),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: session.items.isEmpty ? null : _closeSession,
            icon: const Icon(Icons.local_shipping, size: 20),
            label: const Text(
              'ปิด Session + ส่ง Docking',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.textGrey(
                context,
              ).withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    final session = _session!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WmsCard(
          child: Column(
            children: [
              Icon(
                MdiIcons.checkCircleOutline,
                color: AppTheme.success,
                size: 56,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sort สำเร็จ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pallet ${session.sortPalletId} ส่ง Docking แล้ว',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textGrey(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'รวม ${session.items.length} Carton',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetForNext,
            icon: Icon(MdiIcons.barcodeScan, size: 20),
            label: const Text(
              'Sort Pallet ถัดไป',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('กลับหน้าหลัก'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textGrey(context),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
