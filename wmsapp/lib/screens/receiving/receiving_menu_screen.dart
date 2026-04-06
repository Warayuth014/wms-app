import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';
import 'scan_po/scan_po_screen.dart';
import 'pending_pallet_screen.dart';

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
    final r = await _api.getPendingPalletLines();
    if (mounted && r.success) {
      setState(() => _pendingPalletCount = r.data!.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Receive — รับสินค้าเข้า',
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

              // ── รับสินค้าจาก PO ──────────────
              _MenuCard(
                icon: MdiIcons.trayArrowDown,
                title: 'รับเอกสาร',
                subtitle: 'สแกน PO Number เพื่อรับสินค้าจาก Supplier',
                color: AppTheme.primary,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanPoScreen(
                        userId: widget.userId,
                        fullName: widget.fullName,
                      ),
                    ),
                  );
                  _loadPendingCount(); // รีเฟรชหลังกลับมา
                },
              ),

              const SizedBox(height: 12),

              // ── ค้างการผูก Pallet ─────────────
              _MenuCard(
                icon: Icons.pallet,
                title: 'ค้างการผูก Pallet',
                subtitle: _pendingPalletCount == 0
                    ? 'ไม่มีรายการค้าง'
                    : 'มี $_pendingPalletCount รายการรอผูก Pallet',
                color: _pendingPalletCount == 0
                    ? AppTheme.textGrey(context)
                    : AppTheme.danger,
                badge: _pendingPalletCount > 0 ? '$_pendingPalletCount' : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PendingPalletScreen(
                        userId: widget.userId,
                        fullName: widget.fullName,
                      ),
                    ),
                  );
                  _loadPendingCount(); // รีเฟรชหลังกลับมา
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// =============================================
// _MenuCard
// =============================================
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 28),
          ],
        ),
      ),
    );
  }
}
