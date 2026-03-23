// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wmsapp/screens/flow2/replenishment_menu_screen.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';
import 'login_screen.dart';
import 'package:wmsapp/screens/flow1/flow1_menu_screen.dart';
import 'package:wmsapp/screens/supervisor/cancel_screen.dart';
import 'package:wmsapp/screens/putaway/putaway_screen.dart';
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
  bool _isOnline = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _listenConnectivity();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      _fullName = prefs.getString('fullName');
      _role = prefs.getString('role');
    });
    _updatePendingCount();
  }

  void _listenConnectivity() {
    ConnectivityService().onStatusChanged.listen((online) async {
      setState(() => _isOnline = online);

      // WiFi กลับมา → sync อัตโนมัติ
      if (online && _pendingCount > 0) {
        final result = await OfflineService().syncQueue();
        if (mounted) {
          if (result.hasErrors) {
            showWarningSnackbar(
              context,
              'Sync บางรายการล้มเหลว: ${result.failed} รายการ',
            );
          } else if (result.total > 0) {
            showSuccessSnackbar(
              context,
              'Sync สำเร็จ ${result.success} รายการ',
            );
          }
          _updatePendingCount();
        }
      }
    });
  }

  Future<void> _updatePendingCount() async {
    final count = await OfflineService().getPendingCount();
    if (mounted) setState(() => _pendingCount = count);
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
    return Scaffold(
      appBar: WmsAppBar(
        title: 'WMS',
        userName: _fullName,
        actions: [
          if (_userId != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'ออกจากระบบ',
              onPressed: _logout,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Offline Banner ──────────────────
          if (!_isOnline) OfflineBanner(pendingCount: _pendingCount),

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
                    _buildUserInfo(),

                  const SizedBox(height: 24),

                  // ── Flow Cards ──────────────
                  const Text(
                    'เลือกการทำงาน',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _FlowCard(
                          icon: const _CompositeIcon(
                            mainIcon: Icons.local_shipping,
                            accentIcon: Icons.south,
                            accentColor: Color(0xFFFFC107),
                          ),
                          title: 'Receive',
                          subtitle: 'รับสินค้าเข้า',
                          gradientColors: const [
                            Color(0xFF1B5E20),
                            Color(0xFF4CAF50),
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
                          icon: const _CompositeIcon(
                            mainIcon: Icons.warehouse,
                            accentIcon: Icons.add,
                            accentColor: Color(0xFF00BCD4),
                          ),
                          title: 'Putaway',
                          subtitle: 'เก็บ Pallet เข้าคลัง',
                          gradientColors: const [
                            Color(0xFF0D47A1),
                            Color(0xFF42A5F5),
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

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _FlowCard(
                          icon: const _CompositeIcon(
                            mainIcon: Icons.inventory_2,
                            accentIcon: Icons.autorenew,
                            accentColor: Color(0xFFFFC107),
                          ),
                          title: 'Replenishment',
                          subtitle: 'เติมสินค้า',
                          gradientColors: const [
                            Color(0xFFE65100),
                            Color(0xFFFF9800),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FlowCard(
                          icon: const _CompositeIcon(
                            mainIcon: Icons.content_cut,
                            accentIcon: Icons.arrow_forward,
                            accentColor: Color(0xFF7C4DFF),
                          ),
                          title: 'Picking',
                          subtitle: 'เบิกสินค้า Pick/Pack',
                          gradientColors: const [
                            Color(0xFF4A148C),
                            Color(0xFF9C27B0),
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
                    ],
                  ),

                  // ── Supervisor Section ──────
                  if (_role == 'SUPERVISOR') ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Supervisor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SupervisorCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CancelScreen(userId: _userId!),
                        ),
                      ),
                    ),
                  ],

                  // ── TEST Section ────────────
                  if (_userId != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'TEST',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TestPickOrderScreen(
                            userId: _userId!,
                            fullName: _fullName!,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.science, color: AppTheme.textGrey),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'สร้าง Pick Order (TEST)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'เลือกสินค้าจาก ReceiptLines แล้วสร้าง Pick Order',
                                    style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppTheme.textGrey),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── Pending Sync ────────────
                  if (_userId != null && _pendingCount > 0) ...[
                    const SizedBox(height: 24),
                    _PendingSyncCard(
                      count: _pendingCount,
                      isOnline: _isOnline,
                      onSync: () async {
                        final result = await OfflineService().syncQueue();
                        if (context.mounted) {
                          result.hasErrors
                              ? showWarningSnackbar(context, result.summary)
                              : showSuccessSnackbar(context, result.summary);
                          _updatePendingCount();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return WmsCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.textGrey),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'กดเลือก Flow เพื่อเข้าสู่ระบบ',
              style: TextStyle(color: AppTheme.textGrey),
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

  Widget _buildUserInfo() {
    return WmsCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _userId ?? '',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
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
// _CompositeIcon — ไอคอนซ้อนสองชั้น
// =============================================
class _CompositeIcon extends StatelessWidget {
  final IconData mainIcon;
  final IconData accentIcon;
  final Color accentColor;

  const _CompositeIcon({
    required this.mainIcon,
    required this.accentIcon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          // shadow layer (depth effect)
          Positioned(
            left: 6,
            top: 6,
            child: Icon(
              mainIcon,
              color: Colors.white.withValues(alpha: 0.18),
              size: 62,
            ),
          ),
          // main icon
          Icon(mainIcon, color: Colors.white, size: 62),
          // accent badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(accentIcon, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================
// _FlowCard
// =============================================
class _FlowCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _FlowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // icon area with gradient + decorative circles
            Container(
              height: 118,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Stack(
                children: [
                  // decorative circle top-right
                  Positioned(
                    right: -22,
                    top: -22,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // decorative circle bottom-left
                  Positioned(
                    left: -12,
                    bottom: -18,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // icon centered
                  Center(child: icon),
                ],
              ),
            ),
            // text area
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// _SupervisorCard
// =============================================
class _SupervisorCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SupervisorCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.approval, color: AppTheme.warning),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancel Approval',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'อนุมัติคำขอยกเลิกรายการ',
                    style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textGrey),
          ],
        ),
      ),
    );
  }
}

// =============================================
// _PendingSyncCard
// =============================================
class _PendingSyncCard extends StatelessWidget {
  final int count;
  final bool isOnline;
  final VoidCallback onSync;

  const _PendingSyncCard({
    required this.count,
    required this.isOnline,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Row(
        children: [
          const Icon(Icons.sync, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'มี $count รายการรอ sync',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isOnline)
            TextButton(onPressed: onSync, child: const Text('Sync เลย'))
          else
            const Text(
              'รอ WiFi',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
