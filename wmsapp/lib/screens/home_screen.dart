// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';
import 'login_screen.dart';
import 'package:wmsapp/screens/flow1/scan_po_screen.dart';
import 'package:wmsapp/screens/flow2/scan_pallet_screen.dart';
import 'package:wmsapp/screens/supervisor/cancel_screen.dart';

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
              'Sync สำเร็จ ${result.success} รายการ ✅',
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
                          icon: Icons.move_to_inbox,
                          title: 'Flow 1',
                          subtitle: 'รับสินค้าเข้า',
                          color: AppTheme.primary,
                          onTap: () async {
                            if (!await _requireLogin()) return;
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanPoScreen(
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
                          icon: Icons.output,
                          title: 'Flow 2',
                          subtitle: 'Unload สินค้า',
                          color: AppTheme.secondary,
                          onTap: () async {
                            if (!await _requireLogin()) return;
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanPalletScreen(
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
// _FlowCard
// =============================================
class _FlowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FlowCard({
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
