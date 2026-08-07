// lib/screens/settings/settings_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../services/api_config_service.dart';
import '../../services/api_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _configService = ApiConfigService();

  final _hostController = TextEditingController();
  final _portController = TextEditingController();

  String? _activeUrl;
  bool _loading = true;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _configService.load();
    _hostController.text = config.host ?? '';
    _portController.text = config.port.toString();
    final active = await ApiService.resolveServerUrl();
    if (!mounted) return;
    setState(() {
      _activeUrl = active;
      _loading = false;
    });
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty || port == null) {
      showWarningSnackbar(context, 'กรุณากรอก IP และ Port ให้ครบ');
      return;
    }

    setState(() => _testing = true);
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      if (!mounted) return;
      showSuccessSnackbar(context, 'เชื่อมต่อ $host:$port สำเร็จ');
    } catch (_) {
      if (!mounted) return;
      showWarningSnackbar(context, 'เชื่อมต่อ $host:$port ไม่ได้');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty || port == null) {
      showWarningSnackbar(context, 'กรุณากรอก IP และ Port ให้ครบ');
      return;
    }

    setState(() => _saving = true);
    await _configService.save(host: host, port: port);
    ApiService.resetBaseUrl();
    final active = await ApiService.resolveServerUrl();

    if (!mounted) return;
    setState(() {
      _activeUrl = active;
      _saving = false;
    });
    showSuccessSnackbar(context, 'บันทึกการตั้งค่าเรียบร้อย');
  }

  Future<void> _clear() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'ล้างค่า Server',
      message: 'ระบบจะกลับไปหา server อัตโนมัติ (localhost / emulator) แทน',
      confirmLabel: 'ล้างค่า',
    );
    if (!confirm) return;

    await _configService.clear();
    ApiService.resetBaseUrl();
    final active = await ApiService.resolveServerUrl();

    if (!mounted) return;
    setState(() {
      _hostController.clear();
      _portController.text = ApiConfigService.defaultPort.toString();
      _activeUrl = active;
    });
    showSuccessSnackbar(context, 'ล้างค่าเรียบร้อย');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WmsAppBar(title: 'ตั้งค่าการเชื่อมต่อ'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Server ที่ใช้งานอยู่',
                      icon: MdiIcons.serverNetwork,
                    ),
                    const SizedBox(height: 10),
                    WmsCard(
                      child: InfoRow(
                        label: 'Base URL',
                        value: _activeUrl ?? '-',
                        bold: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'ตั้งค่า IP / Port เอง',
                      icon: MdiIcons.cogOutline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ใช้ตอนย้ายเครื่อง หรือทดสอบด้วยมือถือ/แท็บเล็ตจริงบนวง network เดียวกัน '
                      '— ไม่ต้องแก้โค้ดอีกต่อไป',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    WmsCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: _hostController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'IP Address',
                              hintText: 'เช่น 192.168.1.50',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '5000',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded,
                                    size: 20),
                            label: const Text('ทดสอบ'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            label: 'บันทึก',
                            icon: Icons.save_rounded,
                            loading: _saving,
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('ล้างค่า (ใช้ auto-detect)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
