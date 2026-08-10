// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../services/api_config_service.dart';
import '../../services/api_service.dart';
import '../../services/connection_probe.dart';
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

  String _protocol = ApiConfigService.defaultProtocol;
  String? _activeUrl;
  bool _loading = true;
  bool _testing = false;
  bool _saving = false;

  String? _hostError;
  String? _portError;

  ConnectionTestResult? _activeStatus;
  bool _probingActive = false;

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
    _protocol = config.protocol;
    final active = await ApiService.resolveServerUrl();
    if (!mounted) return;
    setState(() {
      _activeUrl = active;
      _loading = false;
    });
    _probeActive();
  }

  Future<void> _probeActive() async {
    final active = _activeUrl;
    if (active == null) return;
    setState(() => _probingActive = true);
    final result = await probeConnection(baseUrl: active);
    if (!mounted) return;
    setState(() {
      _activeStatus = result;
      _probingActive = false;
    });
  }

  bool _validateFields() {
    final hostError = validateHost(_hostController.text);
    final portError = validatePort(_portController.text);
    setState(() {
      _hostError = hostError;
      _portError = portError;
    });
    return hostError == null && portError == null;
  }

  Future<void> _testConnection() async {
    if (!_validateFields()) return;

    final host = _hostController.text.trim();
    final port = int.parse(_portController.text.trim());

    setState(() => _testing = true);
    final result = await probeConnection(baseUrl: '$_protocol://$host:$port');
    if (!mounted) return;
    setState(() => _testing = false);

    if (result.ok) {
      showSuccessSnackbar(context, result.message);
    } else {
      showWarningSnackbar(context, result.message);
    }
  }

  Future<void> _save() async {
    if (!_validateFields()) return;

    final host = _hostController.text.trim();
    final port = int.parse(_portController.text.trim());

    setState(() => _saving = true);
    await _configService.save(host: host, port: port, protocol: _protocol);
    ApiService.resetBaseUrl();
    final active = await ApiService.resolveServerUrl();

    if (!mounted) return;
    setState(() {
      _activeUrl = active;
      _saving = false;
    });
    showSuccessSnackbar(context, 'บันทึกการตั้งค่าเรียบร้อย');
    _probeActive();
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
      _protocol = ApiConfigService.defaultProtocol;
      _hostError = null;
      _portError = null;
      _activeUrl = active;
    });
    showSuccessSnackbar(context, 'ล้างค่าเรียบร้อย');
    _probeActive();
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InfoRow(
                            label: 'Base URL',
                            value: _activeUrl ?? '-',
                            bold: true,
                          ),
                          const SizedBox(height: 10),
                          _buildStatusRow(),
                        ],
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
                          _buildProtocolSelector(),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _hostController,
                            keyboardType: TextInputType.text,
                            onChanged: (_) {
                              if (_hostError != null) {
                                setState(
                                  () => _hostError = validateHost(
                                    _hostController.text,
                                  ),
                                );
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'IP Address',
                              hintText: 'เช่น 192.168.1.50',
                              prefixIcon: const Icon(Icons.dns_outlined),
                              errorText: _hostError,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              if (_portError != null) {
                                setState(
                                  () => _portError = validatePort(
                                    _portController.text,
                                  ),
                                );
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Port',
                              hintText: '5000',
                              prefixIcon: const Icon(Icons.numbers_rounded),
                              errorText: _portError,
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
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.wifi_tethering_rounded,
                                    size: 20,
                                  ),
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

  Widget _buildProtocolSelector() {
    return Row(
      children: [
        Text(
          'Protocol',
          style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('HTTP'),
          selected: _protocol == 'http',
          onSelected: (_) => setState(() => _protocol = 'http'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('HTTPS'),
          selected: _protocol == 'https',
          onSelected: (_) => setState(() => _protocol = 'https'),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    if (_probingActive) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'กำลังตรวจสอบ...',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
          ),
        ],
      );
    }

    final status = _activeStatus;
    final color = status == null
        ? Colors.grey
        : (status.ok ? AppTheme.success : AppTheme.danger);
    final label = status?.message ?? 'ยังไม่ได้ตรวจสอบ';

    return InkWell(
      onTap: _probeActive,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textGrey(context),
              ),
            ),
          ),
          Icon(Icons.refresh, size: 16, color: AppTheme.textGrey(context)),
        ],
      ),
    );
  }
}
