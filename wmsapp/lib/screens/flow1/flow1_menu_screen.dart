import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import 'scan_po_screen.dart';
import 'package:wmsapp/screens/flow1/return_screen.dart';

class Flow1MenuScreen extends StatelessWidget {
  final String userId;
  final String fullName;

  const Flow1MenuScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(title: 'Receive — รับสินค้าเข้า', userName: fullName),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เลือกประเภทการรับสินค้า',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ── รับสินค้าจาก PO ──────────────
            _MenuCard(
              icon: Icons.move_to_inbox,
              title: 'รับสินค้าจาก PO',
              subtitle: 'สแกน PO Number เพื่อรับสินค้าจาก Supplier',
              color: AppTheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ScanPoScreen(userId: userId, fullName: fullName),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── รับสินค้าคืน ─────────────────
            _MenuCard(
              icon: Icons.replay,
              title: 'รับสินค้าคืน',
              subtitle: 'สแกน Order Number เพื่อรับสินค้าคืนจากลูกค้า',
              color: AppTheme.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReturnScreen(userId: userId, fullName: fullName),
                ),
              ),
            ),
          ],
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

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
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
            const Icon(Icons.chevron_right, color: Colors.white70, size: 28),
          ],
        ),
      ),
    );
  }
}
