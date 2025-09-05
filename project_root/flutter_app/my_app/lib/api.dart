// lib/api.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';

class Api {
  static const base = String.fromEnvironment(
    'BACKEND_BASE',
    defaultValue: 'http://192.168.0.169:5000', // 模擬器；真機請改成 http://<你的PC內網IP>:5000
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
}
