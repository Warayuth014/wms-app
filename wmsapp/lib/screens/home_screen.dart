// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wmsapp/screens/flow2/replenishment_menu_screen.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'package:wmsapp/screens/flow1/flow1_menu_screen.dart';
import 'package:wmsapp/screens/supervisor/part_image_screen.dart';
import 'package:wmsapp/screens/putaway/putaway_screen.dart';
import 'package:wmsapp/screens/putaway/putaway_prework_screen.dart';
import 'package:wmsapp/screens/picking/picking_session_screen.dart';
import 'package:wmsapp/screens/test/test_pick_order_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userId;
  String? _fullName;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      _fullName = prefs.getString('fullName');
      _role = prefs.getString('role');
    });
  }


  // ── ตรวจ login ก่อนเข้า flow ─────────────────
  Future<bool> _requireLogin() async {
    if (_userId != null) return true;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () {
            Navigator.pop(context);
            _loadUser();
          },
        ),
      ),
    );
    return _userId != null;
  }

  Future<void> _logout() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'ออกจากระบบ',
      message: 'ต้องการออกจากระบบใช่ไหม?',
      confirmLabel: 'ออกจากระบบ',
      isDanger: true,
    );
    if (!confirm) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _userId = null;
      _fullName = null;
      _role = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                MdiIcons.warehouse,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('WMS'),
          ],
        ),
        actions: [
          // ── Dark mode toggle ──
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () => themeProvider.toggle(),
          ),
          if (_userId != null)
            IconButton(
              icon: Icon(
                Icons.logout_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              tooltip: 'ออกจากระบบ',
              onPressed: _logout,
            ),
        ],
      ),
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
                    // ── User Info / Login ───────
                    if (_userId == null)
                      _buildLoginPrompt()
                    else
                      _buildUserCard(),

                    const SizedBox(height: 24),

                    // ── Flow Cards ──────────────
                    SectionHeader(
                      title: 'เลือกการทำงาน',
                      icon: MdiIcons.viewDashboardOutline,
                    ),
                    const SizedBox(height: 14),

                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FlowCard(
                            icon: MdiIcons.truckDeliveryOutline,
                            title: 'Receive',
                            subtitle: 'รับสินค้าเข้า',
                            gradient: const [
                              Color(0xFF1B5E20),
                              Color(0xFF43A047),
                            ],
                            onTap: () async {
                              if (!await _requireLogin()) return;
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Flow1MenuScreen(
                                    userId: _userId!,
                                    fullName: _fullName!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlowCard(
                            icon: MdiIcons.forklift,
                            title: 'Putaway for Receive',
                            subtitle: 'เก็บ Pallet เข้าคลัง',
                            gradient: const [
                              Color(0xFF0D47A1),
                              Color(0xFF1E88E5),
                            ],
                            onTap: () async {
                              if (!await _requireLogin()) return;
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PutawayScreen(
                                    userId: _userId!,
                                    fullName: _fullName!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )),

                    const SizedBox(height: 12),

                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FlowCard(
                            icon: MdiIcons.clipboardCheckOutline,
                            title: 'Putaway for Prework',
                            subtitle: 'Prework Station',
                            gradient: const [
                              Color(0xFF004D40),
                              Color(0xFF00897B),
                            ],
                            onTap: () async {
                              if (!await _requireLogin()) return;
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PutawayPreworkScreen(
                                    userId: _userId!,
                                    fullName: _fullName!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlowCard(
                            icon: MdiIcons.packageVariantPlus,
                            title: 'Replenishment',
                            subtitle: 'เติมสินค้า',
                            gradient: const [
                              Color(0xFFE65100),
                              Color(0xFFFB8C00),
                            ],
                            onTap: () async {
                              if (!await _requireLogin()) return;
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReplenishmentMenuScreen(
                                    userId: _userId!,
                                    fullName: _fullName!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )),

                    const SizedBox(height: 12),

                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FlowCard(
                            icon: MdiIcons.cartArrowDown,
                            title: 'Picking',
                            subtitle: 'เบิกสินค้า Pick/Pack',
                            gradient: const [
                              Color(0xFF4A148C),
                              Color(0xFF8E24AA),
                            ],
                            onTap: () async {
                              if (!await _requireLogin()) return;
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PickingSessionScreen(
                                    userId: _userId!,
                                    fullName: _fullName!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    )),

                    // ── Supervisor Section ──────
                    if (_role == 'SUPERVISOR') ...[
                      const SizedBox(height: 28),
                      SectionHeader(
                        title: 'Supervisor',
                        icon: MdiIcons.shieldAccountOutline,
                      ),
                      const SizedBox(height: 14),
                      _ActionCard(
                        icon: MdiIcons.imageEditOutline,
                        iconColor: AppTheme.primary,
                        title: 'จัดการรูปสินค้า',
                        subtitle: 'อัปโหลด/แก้ไขรูปภาพ Parts',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PartImageScreen(
                              userId: _userId!,
                              fullName: _fullName!,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── TEST Section ────────────
                    if (_userId != null) ...[
                      const SizedBox(height: 28),
                      SectionHeader(title: 'TEST', icon: MdiIcons.flaskOutline),
                      const SizedBox(height: 14),
                      _ActionCard(
                        icon: MdiIcons.flaskOutline,
                        iconColor: AppTheme.textGrey(context),
                        title: 'สร้าง Pick Order (TEST)',
                        subtitle: 'เลือกสินค้าจาก ReceiptLines',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TestPickOrderScreen(
                              userId: _userId!,
                              fullName: _fullName!,
                            ),
                          ),
                        ),
                      ),
                    ],


                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return WmsCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'กดเลือก Flow เพื่อเข้าสู่ระบบ',
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    onLoginSuccess: () {
                      Navigator.pop(context);
                      _loadUser();
                    },
                  ),
                ),
              );
            },
            child: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return WmsCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Center(
              child: Text(
                (_fullName ?? '?')[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userId ?? '',
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(_role ?? ''),
        ],
      ),
    );
  }
}

// =============================================
// _FlowCard — modern gradient card
// =============================================
class _FlowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _FlowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: gradient.first.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          child: Stack(
            children: [
              // decorative circle
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -10,
                bottom: -10,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // content
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
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
// _ActionCard — for supervisor / test items
// =============================================
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textGrey(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

