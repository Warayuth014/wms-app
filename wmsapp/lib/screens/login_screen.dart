// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/theme.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ───────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.warehouse,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'WMS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const Text(
                  'Warehouse Management System',
                  style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 40),

                // ── Form ───────────────────────
                WmsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เข้าสู่ระบบ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // เลือก User
                      DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: _selectedUser,
                        hint: const Text('เลือกผู้ใช้งาน'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'ผู้ใช้งาน',
                          prefixIcon: Icon(Icons.person),
                        ),
                        // แสดงแค่ชื่อตอนเลือกแล้ว (ไม่ overflow)
                        selectedItemBuilder: (context) => _users
                            .map(
                              (u) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  u['fullName']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        items: _users
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(u['fullName']!),
                                    Text(
                                      u['role']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedUser = v),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: _passController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.danger,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppTheme.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      PrimaryButton(
                        label: 'เข้าสู่ระบบ',
                        icon: Icons.login,
                        loading: _loading,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'รหัสผ่านทดสอบ: 1234',
                          style: TextStyle(
                            color: AppTheme.textGrey,
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
    );
  }
}
