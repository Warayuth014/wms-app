// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:wmsapp/screens/unload/unload_menu/unload_menu_screen.dart';
import 'package:wmsapp/services/auth_session_service.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'package:wmsapp/screens/receiving/receiving_menu/receiving_menu_screen.dart';
import 'package:wmsapp/screens/supervisor/part_image_screen.dart';
import 'package:wmsapp/screens/putaway/putaway_main/putaway_screen.dart';
import 'package:wmsapp/screens/putaway/putaway_prework/putaway_prework_screen.dart';
import 'package:wmsapp/screens/picking/picking_session/picking_session_screen.dart';
import 'package:wmsapp/screens/packing/packing_screen.dart';
import 'package:wmsapp/screens/sorting/sorting_screen.dart';
import 'package:wmsapp/screens/test/test_pick_order_screen.dart';
import 'home/widgets/cards/home_action_card.dart';
import 'home/widgets/cards/home_flow_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionService = const AuthSessionService();
  String? _userId;
  String? _fullName;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = await _sessionService.loadSession();
    setState(() {
      _userId = session.userId;
      _fullName = session.fullName;
      _role = session.role;
    });
  }

  Future<void> _openLogin() async {
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
  }

  // ── ตรวจ login ก่อนเข้า flow ─────────────────
  Future<bool> _requireLogin() async {
    if (_userId != null) return true;

    await _openLogin();
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

    await _sessionService.clearSession();
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
              child: Icon(MdiIcons.warehouse, color: Colors.white, size: 20),
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
                            child: HomeFlowCard(
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
                                    builder: (_) => ReceivingMenuScreen(
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
                            child: HomeFlowCard(
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
                      ),
                    ),

                    const SizedBox(height: 12),

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: HomeFlowCard(
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
                            child: HomeFlowCard(
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
                                    builder: (_) => UnloadMenuScreen(
                                      userId: _userId!,
                                      fullName: _fullName!,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: HomeFlowCard(
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
                          Expanded(
                            child: HomeFlowCard(
                              icon: MdiIcons.packageVariant,
                              title: 'Packing',
                              subtitle: 'แพ็คสินค้า',
                              gradient: const [
                                Color.fromARGB(255, 218, 52, 52),
                                Color.fromARGB(255, 255, 66, 33),
                              ],
                              onTap: () async {
                                if (!await _requireLogin()) return;
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PackingScreen(
                                      userId: _userId!,
                                      fullName: _fullName!,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: HomeFlowCard(
                              icon: MdiIcons.sortVariant,
                              title: 'Sorting',
                              subtitle: 'คัดแยกสินค้าลง Pallet',
                              gradient: const [
                                Color(0xFF00695C),
                                Color(0xFF00897B),
                              ],
                              onTap: () async {
                                if (!await _requireLogin()) return;
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SortingScreen(
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
                      ),
                    ),

                    // ── Supervisor Section ──────
                    if (_role == 'SUPERVISOR') ...[
                      const SizedBox(height: 28),
                      SectionHeader(
                        title: 'Supervisor',
                        icon: MdiIcons.shieldAccountOutline,
                      ),
                      const SizedBox(height: 14),
                      HomeActionCard(
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

                    // ── Manual Operations ───────
                    if (_role == 'SUPERVISOR') ...[
                      const SizedBox(height: 28),
                      SectionHeader(
                        title: 'Manual Operations',
                        icon: MdiIcons.playlistPlus,
                      ),
                      const SizedBox(height: 14),
                      HomeActionCard(
                        icon: MdiIcons.playlistPlus,
                        iconColor: AppTheme.primary,
                        title: 'สร้าง Pick Order (Manual)',
                        subtitle: 'เลือกสินค้าจาก Pallet ที่พร้อม Pick',
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
