// lib/screens/unload/unload_menu/unload_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../unload_screen.dart';
import '../load_to_basket/load_to_basket_screen.dart';

class UnloadMenuScreen extends StatelessWidget {
  final String userId;
  final String fullName;

  const UnloadMenuScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WmsAppBar(
        title: 'Replenishment - Unload',
        userName: fullName,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuCard(
                icon: MdiIcons.trayArrowUp,
                color: AppTheme.primary,
                title: 'Unload',
                subtitle: 'Unload สินค้าจาก Pallet ลงสถานี',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UnloadScreen(
                      userId: userId,
                      fullName: fullName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: MdiIcons.basketOutline,
                color: AppTheme.teal,
                title: 'Load to Basket',
                subtitle: 'โหลดสินค้าที่ Unload แล้วเข้า Basket',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoadToBasketScreen(
                      userId: userId,
                      fullName: fullName,
                    ),
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

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textGrey(context))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
