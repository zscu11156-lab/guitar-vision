// lib/api.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';

class Api {
  static const base = String.fromEnvironment(
    'BACKEND_BASE',
    // 模擬器請用 10.0.2.2；真機才用你的內網 IP（例如 192.168.x.x）
    defaultValue: 'http://123.193.80.150:5000',
  );

  static final _dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// 影像：不帶 target
  /// （若你想交給後端做鏡像，可加 mirror 參數版本；目前你已在前端反轉，保持現狀即可）
  static Future<Map<String, dynamic>> predictBytes(Uint8List jpgBytes) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(jpgBytes, filename: 'frame.jpg'),
    });
    final r = await _dio.post('/predict', data: form);
    return Map<String, dynamic>.from(r.data);
  }

  /// 影像：帶 target；可選 mirror（預設 false）。
  /// 現在你已在前端把前鏡頭做水平反轉 => mirror 預設 false 就好。
  static Future<Map<String, dynamic>> predictWithTarget(
    Uint8List jpgBytes,
    String targetChord, {
    bool mirror = false,
  }) async {
    final form = FormData.fromMap({
      'target': targetChord,
      if (mirror) 'mirror': '1', // 只在需要時才交給後端做鏡像
      'image': MultipartFile.fromBytes(jpgBytes, filename: 'frame.jpg'),
    });
    final r = await _dio.post('/predict', data: form);
    return Map<String, dynamic>.from(r.data);
  }

  /// 音訊：每 250ms 傳「最後 1 秒」的 mono 16-bit PCM 到 /audio_chunk
  /// 後端會回 { chord, conf, energy, vote }
  static Future<Map<String, dynamic>> audioChunk(
    Uint8List pcm1sBytes, {
    int sr = 44100,
  }) async {
    final r = await _dio.post(
      '/audio_chunk',
      data: pcm1sBytes, // 直接丟原始 bytes
      queryParameters: {'sr': sr},
      options: Options(
        contentType: 'application/octet-stream', // 二進位資料
        responseType: ResponseType.json,
      ),
    );
    return Map<String, dynamic>.from(r.data);
  }

  /// Ping 測試（後端回純文字 "pong"）
  static Future<String> ping() async {
    final r = await _dio.get(
      '/ping',
      options: Options(responseType: ResponseType.plain),
    );
    return r.data?.toString() ?? '';
  }

  /// 健康檢查（JSON）
  static Future<Map<String, dynamic>> health() async {
    final r = await _dio.get('/health');
    return Map<String, dynamic>.from(r.data);
  }
}
