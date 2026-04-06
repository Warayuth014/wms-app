import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../services/api_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../pending_pallet/pending_pallet_screen.dart';
import '../scan_po/scan_po_screen.dart';
import 'widgets/receiving_menu_card.dart';

class ReceivingMenuScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const ReceivingMenuScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<ReceivingMenuScreen> createState() => _ReceivingMenuScreenState();
}

class _ReceivingMenuScreenState extends State<ReceivingMenuScreen> {
  final _api = ApiService();
  int _pendingPalletCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final result = await _api.getPendingPalletLines();
    if (mounted && result.success) {
      setState(() => _pendingPalletCount = result.data!.length);
    }
  }

  Future<void> _openScanPo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanPoScreen(
          userId: widget.userId,
          fullName: widget.fullName,
        ),
      ),
    );
    _loadPendingCount();
  }

  Future<void> _openPendingPallet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingPalletScreen(
          userId: widget.userId,
          fullName: widget.fullName,
        ),
      ),
    );
    _loadPendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Receive - รับสินค้าเข้า',
        userName: widget.fullName,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เลือกประเภทการรับสินค้า',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              ReceivingMenuCard(
                icon: MdiIcons.trayArrowDown,
                title: 'รับเอกสาร',
                subtitle: 'สแกน PO Number เพื่อรับสินค้าจาก Supplier',
                color: AppTheme.primary,
                onTap: _openScanPo,
              ),
              const SizedBox(height: 12),
              ReceivingMenuCard(
                icon: Icons.pallet,
                title: 'ค้างการผูก Pallet',
                subtitle: _pendingPalletCount == 0
                    ? 'ไม่มีรายการค้าง'
                    : 'มี $_pendingPalletCount รายการรอผูก Pallet',
                color: _pendingPalletCount == 0
                    ? AppTheme.textGrey(context)
                    : AppTheme.danger,
                badge: _pendingPalletCount > 0 ? '$_pendingPalletCount' : null,
                onTap: _openPendingPallet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
