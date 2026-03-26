// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Mock users ตรงกับ seed data
  final _users = [
    {'userId': 'USR-001', 'fullName': 'สมชาย ใจดี', 'role': 'OPERATOR'},
    {'userId': 'USR-002', 'fullName': 'สมหญิง รักงาน', 'role': 'OPERATOR'},
    {'userId': 'USR-003', 'fullName': 'สมศักดิ์ หัวหน้า', 'role': 'SUPERVISOR'},
  ];

  Map<String, dynamic>? _selectedUser;
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _passController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_selectedUser == null) {
      setState(() => _error = 'กรุณาเลือกผู้ใช้งาน');
      return;
    }
    if (_passController.text.isEmpty) {
      setState(() => _error = 'กรุณาใส่รหัสผ่าน');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Mock: password = "1234" ทุก user
    await Future.delayed(const Duration(milliseconds: 500));

    if (_passController.text != '1234') {
      setState(() {
        _loading = false;
        _error = 'รหัสผ่านไม่ถูกต้อง';
      });
      return;
    }

    // บันทึก login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', _selectedUser!['userId']!);
    await prefs.setString('fullName', _selectedUser!['fullName']!);
    await prefs.setString('role', _selectedUser!['role']!);

    setState(() => _loading = false);
    widget.onLoginSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                  : [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo ───────────────────────
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.warehouse_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'WMS',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      Text(
                        'Warehouse Management System',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Form ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'เลือกผู้ใช้งานและใส่รหัสผ่าน',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textGrey(context),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── User cards ──────────────
                            ...List.generate(_users.length, (i) {
                              final u = _users[i];
                              final isSelected = _selectedUser == u;
                              final isSuper = u['role'] == 'SUPERVISOR';
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i < _users.length - 1 ? 8 : 0,
                                ),
                                child: Material(
                                  color: isSelected
                                      ? AppTheme.primary.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                    onTap: () =>
                                        setState(() => _selectedUser = u),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSm,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.border(context),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primary
                                                  : AppTheme.textGrey(
                                                      context,
                                                    ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusSm,
                                                  ),
                                            ),
                                            child: Icon(
                                              isSuper
                                                  ? Icons.shield_rounded
                                                  : Icons.person_rounded,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppTheme.textGrey(context),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  u['fullName']!,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: AppTheme.textPrimary(
                                                      context,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${u['userId']} · ${u['role']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textGrey(
                                                      context,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppTheme.primary,
                                              size: 22,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 20),

                            // ── Password ─────────────────
                            TextField(
                              controller: _passController,
                              obscureText: _obscure,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'รหัสผ่าน',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              onSubmitted: (_) => _login(),
                            ),

                            // ── Error ────────────────────
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: _error != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.danger.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.danger.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: AppTheme.danger,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _error!,
                                                style: const TextStyle(
                                                  color: AppTheme.danger,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 24),

                            PrimaryButton(
                              label: 'เข้าสู่ระบบ',
                              icon: Icons.login_rounded,
                              loading: _loading,
                              onPressed: _login,
                            ),

                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                'รหัสผ่านทดสอบ: 1234',
                                style: TextStyle(
                                  color: AppTheme.textGrey(
                                    context,
                                  ).withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
