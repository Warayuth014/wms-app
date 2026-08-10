// lib/services/connection_probe.dart
//
// เช็คว่า server ที่ปลายทางเป็น WmsApi จริง ไม่ใช่แค่ port เปิด (raw socket connect
// หลอกได้ถ้ามี service อื่นฟังพอร์ตเดียวกันอยู่) — ยิง GET /api/health แล้วอ่าน payload

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ConnectionTestResult {
  final bool ok;
  final int elapsedMs;
  final String message;
  final int? statusCode;

  const ConnectionTestResult({
    required this.ok,
    required this.elapsedMs,
    required this.message,
    this.statusCode,
  });
}

bool _isHealthPayload(String body) {
  try {
    final json = jsonDecode(body);
    return json is Map && json['service'] == 'WmsApi' && json['ok'] == true;
  } catch (_) {
    return false;
  }
}

/// [baseUrl] เช่น 'http://192.168.1.50:5000' (ไม่มี /api ต่อท้าย)
Future<ConnectionTestResult> probeConnection({
  required String baseUrl,
  Duration timeout = const Duration(seconds: 5),
  http.Client? client,
}) async {
  final watch = Stopwatch()..start();
  final owned = client == null;
  final httpClient = client ?? http.Client();

  Uri uri;
  try {
    uri = Uri.parse('$baseUrl/api/health');
    if (!uri.hasScheme || uri.host.isEmpty) throw const FormatException();
  } on FormatException {
    if (owned) httpClient.close();
    return const ConnectionTestResult(
      ok: false,
      elapsedMs: 0,
      message: 'ที่อยู่ server ไม่ถูกต้อง',
    );
  }

  try {
    final response = await httpClient.get(uri).timeout(timeout);
    watch.stop();
    final code = response.statusCode;
    final reachedApi = code >= 200 && code < 300;
    final isWms = reachedApi && _isHealthPayload(response.body);

    return ConnectionTestResult(
      ok: isWms,
      statusCode: code,
      elapsedMs: watch.elapsedMilliseconds,
      message: isWms
          ? 'เชื่อมต่อสำเร็จ · ${watch.elapsedMilliseconds} ms'
          : reachedApi
          ? 'เซิร์ฟเวอร์ตอบกลับ แต่ไม่ใช่ WmsApi'
          : 'ตอบกลับ HTTP $code — ไม่ใช่เซิร์ฟเวอร์ WmsApi',
    );
  } on TimeoutException {
    watch.stop();
    return ConnectionTestResult(
      ok: false,
      elapsedMs: watch.elapsedMilliseconds,
      message: 'ไม่ตอบใน ${timeout.inSeconds} วินาที — ตรวจ IP และพอร์ต',
    );
  } on HandshakeException {
    watch.stop();
    return ConnectionTestResult(
      ok: false,
      elapsedMs: watch.elapsedMilliseconds,
      message: 'ใบรับรอง HTTPS ไม่ผ่าน — ลองใช้ HTTP หรือแก้ใบรับรอง',
    );
  } on SocketException {
    watch.stop();
    return ConnectionTestResult(
      ok: false,
      elapsedMs: watch.elapsedMilliseconds,
      message: 'ติดต่อที่อยู่นี้ไม่ได้ — ตรวจสัญญาณและเครื่อง server',
    );
  } on http.ClientException catch (e) {
    watch.stop();
    return ConnectionTestResult(
      ok: false,
      elapsedMs: watch.elapsedMilliseconds,
      message: 'เชื่อมต่อไม่สำเร็จ: ${e.message}',
    );
  } finally {
    if (owned) httpClient.close();
  }
}