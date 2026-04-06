// lib/screens/unload/unload_menu/unload_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';
import '../unload_session/unload_screen.dart';
import 'widgets/unload_menu_card.dart';

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
        title: 'Unload',
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
              UnloadMenuCard(
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
            ],
          ),
        ),
      ),
    );
  }
}
