// lib/services/api_config_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// เก็บ IP/Port/Protocol ของ backend ที่ผู้ใช้ตั้งเอง (ตั้งค่าจาก Settings)
/// แทนการ hardcode IP ในโค้ด — ย้ายเครื่อง/เปลี่ยนวง network ก็แค่ตั้งค่าใหม่
class ApiConfigService {
  const ApiConfigService();

  static const _keyHost = 'apiHost';
  static const _keyPort = 'apiPort';
  static const _keyProtocol = 'apiProtocol';

  static const defaultPort = 5000;
  static const defaultProtocol = 'http';

  Future<({String? host, int port, String protocol})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      host: prefs.getString(_keyHost),
      port: prefs.getInt(_keyPort) ?? defaultPort,
      protocol: prefs.getString(_keyProtocol) ?? defaultProtocol,
    );
  }

  /// คืน base URL ที่ผู้ใช้ตั้งเอง (เช่น 'http://192.168.1.50:5000') หรือ null ถ้ายังไม่ตั้ง
  Future<String?> getCustomBase() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_keyHost);
    if (host == null || host.trim().isEmpty) return null;
    final port = prefs.getInt(_keyPort) ?? defaultPort;
    final protocol = prefs.getString(_keyProtocol) ?? defaultProtocol;
    return '$protocol://$host:$port';
  }

  Future<void> save({
    required String host,
    required int port,
    required String protocol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host.trim());
    await prefs.setInt(_keyPort, port);
    await prefs.setString(_keyProtocol, protocol);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHost);
    await prefs.remove(_keyPort);
    await prefs.remove(_keyProtocol);
  }
}

/// เช็ครูปแบบ host ที่กรอก — ดักเคสพิมพ์ผิดที่พบบ่อย (ใส่ http:// หรือ port ปนมาในช่องเดียวกัน)
String? validateHost(String host) {
  final trimmed = host.trim();
  if (trimmed.isEmpty) return 'กรุณาใส่ IP หรือชื่อเครื่อง';
  if (trimmed.contains('://') || trimmed.toLowerCase().startsWith('http')) {
    return 'ใส่เฉพาะ IP/hostname ไม่ต้องมี http:// (เลือก Protocol ด้านล่างแทน)';
  }
  if (trimmed.contains(' ')) return 'ห้ามมีช่องว่าง';
  if (trimmed.contains(':')) return 'พอร์ตให้ใส่ในช่อง Port แยกต่างหาก';
  if (trimmed.contains('/')) return 'ห้ามมี / ในช่องนี้';
  return null;
}

/// เช็ครูปแบบ port ที่กรอก
String? validatePort(String portText) {
  final trimmed = portText.trim();
  if (trimmed.isEmpty) return 'กรุณาใส่ Port';
  final port = int.tryParse(trimmed);
  if (port == null) return 'พอร์ตต้องเป็นตัวเลข';
  if (port < 1 || port > 65535) return 'พอร์ตต้องอยู่ระหว่าง 1-65535';
  return null;
}
