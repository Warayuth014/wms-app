import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/wms_models.dart';

part 'api/upload_api.dart';
part 'api/receiving_api.dart';
part 'api/unload_api.dart';
part 'api/putaway_api.dart';
part 'api/picking_api.dart';
part 'api/packing_api.dart';

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResult.success(this.data) : success = true, error = null, statusCode = 200;

  ApiResult.error(this.error, {this.statusCode}) : success = false, data = null;

  bool get isNotFound => statusCode == 404;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  static const _physicalIp = '192.168.1.42';
  static const _port = 5000;
  static String? _cachedBase;

  final _headers = {'Content-Type': 'application/json'};

  static Future<String> _resolveBase() async {
    if (_cachedBase != null) return _cachedBase!;

    final candidates = <String>[
      if (Platform.isAndroid) 'http://10.0.2.2:$_port',
      if (!Platform.isAndroid) 'http://localhost:$_port',
      'http://$_physicalIp:$_port',
    ];

    for (final base in candidates) {
      final uri = Uri.parse(base);
      try {
        final socket = await Socket.connect(
          uri.host,
          uri.port,
          timeout: const Duration(seconds: 1),
        );
        socket.destroy();
        _cachedBase = '$base/api';
        return _cachedBase!;
      } catch (_) {}
    }

    _cachedBase = 'http://$_physicalIp:$_port/api';
    return _cachedBase!;
  }

  static void resetBaseUrl() => _cachedBase = null;

  static Future<String> resolveServerUrl() async {
    final base = await _resolveBase();
    return base.replaceAll('/api', '');
  }

  Future<ApiResult<Map<String, dynamic>>> _get(String path) async {
    try {
      final base = await ApiService._resolveBase();
      final response = await http
          .get(Uri.parse('$base$path'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return _handle(response);
    } on SocketException {
      return ApiResult.error('ไม่สามารถเชื่อมต่อ server ได้');
    } on TimeoutException {
      return ApiResult.error('การเชื่อมต่อหมดเวลา กรุณาลองใหม่');
    } catch (error) {
      return ApiResult.error('เกิดข้อผิดพลาด: $error');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final base = await ApiService._resolveBase();
      final response = await http
          .post(
            Uri.parse('$base$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return _handle(response);
    } on SocketException {
      return ApiResult.error('ไม่สามารถเชื่อมต่อ server ได้');
    } on TimeoutException {
      return ApiResult.error('การเชื่อมต่อหมดเวลา กรุณาลองใหม่');
    } catch (error) {
      return ApiResult.error('เกิดข้อผิดพลาด: $error');
    }
  }

  ApiResult<Map<String, dynamic>> _handle(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      return ApiResult.error(
        'Server ส่งข้อมูลไม่ถูกต้อง (${response.statusCode})',
      );
    }

    final body = decoded is List
        ? <String, dynamic>{'items': decoded}
        : decoded as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResult.success(body);
    }

    final error = body['error']?.toString();
    final detail = body['detail']?.toString();
    final message = (error != null && detail != null)
        ? '$error\n$detail'
        : error ?? detail ?? 'เกิดข้อผิดพลาด (${response.statusCode})';

    return ApiResult.error(message, statusCode: response.statusCode);
  }

  Future<ApiResult<Map<String, dynamic>>> _uploadFile(
    String path,
    File file, {
    Map<String, String> fields = const {},
  }) async {
    try {
      final base = await ApiService._resolveBase();
      final uri = Uri.parse('$base$path');
      final request = http.MultipartRequest('POST', uri);

      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      return _handle(response);
    } on SocketException {
      return ApiResult.error('ไม่สามารถเชื่อมต่อ server ได้');
    } on TimeoutException {
      return ApiResult.error('การเชื่อมต่อหมดเวลา กรุณาลองใหม่');
    } catch (error) {
      return ApiResult.error('เกิดข้อผิดพลาด: $error');
    }
  }
}
