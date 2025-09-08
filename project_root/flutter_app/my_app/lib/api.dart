// lib/api.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';

class Api {
  static const base = String.fromEnvironment(
    'BACKEND_BASE',
    // 模擬器請用 10.0.2.2；真機才用你的內網 IP（例如 192.168.x.x）
    defaultValue: 'http://123.193.80.150:5000',
  );

  static final _dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static Future<Map<String, dynamic>> predictBytes(Uint8List jpgBytes) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(jpgBytes, filename: 'frame.jpg'),
    });
    final r = await _dio.post('/predict', data: form);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> predictWithTarget(
      Uint8List jpgBytes, String targetChord) async {
    final form = FormData.fromMap({
      'target': targetChord,
      'image': MultipartFile.fromBytes(jpgBytes, filename: 'frame.jpg'),
    });
    final r = await _dio.post('/predict', data: form);
    return Map<String, dynamic>.from(r.data);
  }

  // ★ 新增：ping 測試
  static Future<Map<String, dynamic>> ping() async {
    final r = await _dio.get('/ping');
    return Map<String, dynamic>.from(r.data);
  }
}