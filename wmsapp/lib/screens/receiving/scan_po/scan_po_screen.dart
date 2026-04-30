// lib/screens/receiving/scan_po/scan_po_screen.dart

import 'package:flutter/material.dart';

import '../../../models/wms_models.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../scan_part/scan_part_screen.dart';
import 'widgets/info/po_info_card.dart';
import 'widgets/info/po_items_list.dart';
import 'widgets/search/po_search_card.dart';
import 'widgets/steps/po_step_indicator.dart';

class ScanPoScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const ScanPoScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<ScanPoScreen> createState() => _ScanPoScreenState();
}

class _ScanPoScreenState extends State<ScanPoScreen> {
  final _poController = TextEditingController();
  final _api = ApiService();

  POResponse? _po;
  bool _loadingPo = false;

  Future<void> _scanPO() async {
    final poId = _poController.text.trim().toUpperCase();
    if (poId.isEmpty) {
      showErrorDialog(context, message: 'กรุณาใส่ PO ID');
      return;
    }

    setState(() {
      _loadingPo = true;
      _po = null;
    });

    final result = await _api.getPO(poId);

    if (!mounted) return;

    if (!result.success) {
      setState(() => _loadingPo = false);
      showErrorDialog(context, message: result.error!);
      return;
    }

    setState(() {
      _po = result.data!;
      _loadingPo = false;
    });
  }

  Future<void> _startReceiving() async {
    final po = _po!;
    final active = await _api.getActiveReceivingSession(po.poId);
    if (!mounted) return;

    ReceivingSession session;

    if (active != null) {
      session = active;
    } else {
      final result = await _api.openReceivingSession(
        poId: po.poId,
        operatorId: widget.userId,
      );
      if (!mounted) return;
      if (!result.success) {
        showErrorDialog(context, message: result.error!);
        return;
      }
      session = result.data!;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanPartScreen(
          userId: widget.userId,
          fullName: widget.fullName,
          session: session,
          po: po,
        ),
      ),
    );

    await _reloadPO();
  }

  Future<void> _reloadPO() async {
    if (_po == null) return;
    final result = await _api.getPO(_po!.poId);
    if (!mounted) return;
    if (result.success) {
      setState(() => _po = result.data!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'รับสินค้าจาก PO', userName: widget.fullName),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PoStepIndicator(),
                    const SizedBox(height: 20),
                    PoSearchCard(
                      controller: _poController,
                      loading: _loadingPo,
                      onSearch: _scanPO,
                    ),
                    const SizedBox(height: 16),
                    if (_po != null) ...[
                      PoInfoCard(po: _po!),
                      const SizedBox(height: 16),
                      PoItemsList(items: _po!.items),
                      const SizedBox(height: 16),
                      if (_po!.status != 'RECEIVED')
                        PrimaryButton(
                          label: 'เริ่มรับสินค้า',
                          icon: Icons.play_arrow,
                          onPressed: _startReceiving,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.success,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'PO นี้รับสินค้าครบแล้ว',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _poController.dispose();
    super.dispose();
  }
}
