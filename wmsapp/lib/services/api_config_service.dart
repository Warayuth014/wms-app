// lib/services/api_config_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// เก็บ IP/Port ของ backend ที่ผู้ใช้ตั้งเอง (ตั้งค่าจาก Settings)
/// แทนการ hardcode IP ในโค้ด — ย้ายเครื่อง/เปลี่ยนวง network ก็แค่ตั้งค่าใหม่
class ApiConfigService {
  const ApiConfigService();

  static const _keyHost = 'apiHost';
  static const _keyPort = 'apiPort';

  static const defaultPort = 5000;

  Future<({String? host, int port})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      host: prefs.getString(_keyHost),
      port: prefs.getInt(_keyPort) ?? defaultPort,
    );
  }

  /// คืน base URL ที่ผู้ใช้ตั้งเอง (เช่น 'http://192.168.1.50:5000') หรือ null ถ้ายังไม่ตั้ง
  Future<String?> getCustomBase() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_keyHost);
    if (host == null || host.trim().isEmpty) return null;
    final port = prefs.getInt(_keyPort) ?? defaultPort;
    return 'http://$host:$port';
  }

  Future<void> save({required String host, required int port}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host.trim());
    await prefs.setInt(_keyPort, port);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHost);
    await prefs.remove(_keyPort);
  }
}
