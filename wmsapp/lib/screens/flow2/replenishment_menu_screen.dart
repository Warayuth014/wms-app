// lib/screens/flow2/replenishment_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import 'unload_screen.dart';
import 'load_basket_screen.dart';
import 'replenish_order_screen.dart';

class ReplenishmentMenuScreen extends StatelessWidget {
  final String userId;
  final String fullName;

  const ReplenishmentMenuScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Replenishment — เติมสินค้า',
        userName: fullName,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เลือกประเภทการเติมสินค้า',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),

              // ── Replenish Orders ──────────────
              // _MenuCard(
              //   icon: MdiIcons.clipboardTextOutline,
              //   title: 'Replenish Orders',
              //   subtitle: 'ดู Order และเติมสินค้าลง Tote (Tote-first workflow)',
              //   color: const Color(0xFF7B1FA2),
              //   onTap: () => Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (_) =>
              //           ReplenishOrderScreen(userId: userId, fullName: fullName),
              //     ),
              //   ),
              // ),
              const SizedBox(height: 12),

              // ── Unload ────────────────────────
              _MenuCard(
                icon: MdiIcons.trayArrowUp,
                title: 'Unload',
                subtitle: 'ขนสินค้าออกจาก Pallet เพื่อเตรียมลงตะกร้า',
                color: AppTheme.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UnloadScreen(userId: userId, fullName: fullName),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Load Basket ───────────────────
              _MenuCard(
                icon: MdiIcons.basketOutline,
                title: 'Load Basket',
                subtitle: 'โหลดสินค้าลงตะกร้าเพื่อส่งไปยังพื้นที่จำหน่าย',
                color: AppTheme.success,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LoadBasketScreen(userId: userId, fullName: fullName),
                  ),
                ),
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
