import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // debugPrint & compute

const _mic = EventChannel('gv.tuner/audioStream');

const STANDARD_TUNING = <String, double>{
  "E2": 82.41,
  "A2": 110.00,
  "D3": 146.83,
  "G3": 196.00,
  "B3": 246.94,
  "E4": 329.63,
};

const STRING_HINT = <String, String>{
  "E2": "第六弦（低音E）",
  "A2": "第五弦（A）",
  "D3": "第四弦（D）",
  "G3": "第三弦（G）",
  "B3": "第二弦（B）",
  "E4": "第一弦（高音E）",
};

class TunerState {
  final double freq; // 偵測頻率
  final String note; // 最接近的弦名
  final double diff; // 與標準差值（Hz）
  final String hint; // 弦提示
  final String advice; // 建議
  const TunerState({
    this.freq = 0,
    this.note = '',
    this.diff = 0,
    this.hint = '',
    this.advice = '—',
  });
  static const empty = TunerState();
}

class TunerEngine {
  final _out = StreamController<TunerState>.broadcast();
  Stream<TunerState> get stream => _out.stream;

  final int _fs = 44100;
  final int _win = 4096; // 解析度更好（~10.8Hz），配合插值

  final List<int> _pcm = [];
  StreamSubscription<dynamic>? _sub;

  Timer? _processTimer; // 每 50ms 嘗試處理一次
  Timer? _reconnectTimer;
  bool _busy = false;
  double _freqEma = 0; // 指數平滑
  final double _emaAlpha = 0.35;
  bool _disposed = false;

  void start() {
    if (_disposed) return;
    if (_sub != null) return;

    debugPrint("Dart: start() called, subscribing EventChannel");

    _sub = _mic.receiveBroadcastStream().listen(
      _onBytes,
      onError: (e) {
        debugPrint("EventChannel error: $e");
        _handleStreamEnd();
      },
      onDone: _handleStreamEnd,
      cancelOnError: true,
    );

    _processTimer ??=
        Timer.periodic(const Duration(milliseconds: 50), (_) => _processOnce());
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _processTimer?.cancel();
    _processTimer = null;
    _pcm.clear();
  }

  void dispose() {
    _disposed = true;
    stop(); // 不 await
    _out.close();
  }

  void _handleStreamEnd([dynamic _]) {
    _sub?.cancel();
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_disposed && _sub == null) start();
    });
  }

  // 收到 PCM (Uint8List) → 轉 Int16 放入暫存
  void _onBytes(dynamic event) {
    if (event is! Uint8List || event.isEmpty) return;
    // debug：看資料有沒有來
    // debugPrint("Got ${event.lengthInBytes} bytes from mic");

    final bd =
        event.buffer.asByteData(event.offsetInBytes, event.lengthInBytes);
    for (int i = 0; i + 1 < bd.lengthInBytes; i += 2) {
      _pcm.add(bd.getInt16(i, Endian.little));
    }
  }

  // 節流處理（50ms 一次）
  Future<void> _processOnce() async {
    if (_busy) return;
    if (_pcm.length < _win) return;

    // 取一窗，50% overlap
    final frame = _pcm.take(_win).toList();
    _pcm.removeRange(0, _win ~/ 2);

    // RMS 門檻：噪聲/靜音不更新
    double sum2 = 0;
    for (final s in frame) {
      sum2 += s * s;
    }
    final rms = math.sqrt(sum2 / frame.length) / 32768.0;
    if (rms < 0.003) {
      _emit(const TunerState(freq: 0));
      return;
    }

    _busy = true;
    try {
      final freq = await compute(_analyzeFreq, {
        'frame': frame,
        'win': _win,
        'fs': _fs,
      });

      final fSmoothed = (_freqEma == 0)
          ? freq
          : (_emaAlpha * freq + (1 - _emaAlpha) * _freqEma);
      _freqEma = fSmoothed;

      // 找最接近的弦
      String closest = '';
      double minDiff = double.infinity;
      for (final e in STANDARD_TUNING.entries) {
        final d = (fSmoothed - e.value).abs();
        if (d < minDiff) {
          minDiff = d;
          closest = e.key;
        }
      }

      final ref = closest.isEmpty ? 0.0 : STANDARD_TUNING[closest]!;
      final diff = fSmoothed - ref;

      String advice;
      if (closest.isEmpty || fSmoothed == 0) {
        advice = '—';
      } else if (diff.abs() < 1) {
        advice = '音準正確，無需調整';
      } else if (diff > 0) {
        advice = '音高偏高，請鬆一點（降低音高）';
      } else {
        advice = '音高偏低，請轉緊一點（提高音高）';
      }

      _emit(TunerState(
        freq: fSmoothed.isFinite ? fSmoothed : 0,
        note: closest,
        diff: diff.isFinite ? diff : 0,
        hint: STRING_HINT[closest] ?? '',
        advice: advice,
      ));
    } finally {
      _busy = false;
    }
  }

  void _emit(TunerState s) {
    if (!_out.isClosed) _out.add(s);
  }
}

/// ==== 背景 Isolate：頻率估計（Hann + FFT + 拋物線插值）====
double _analyzeFreq(Map<String, dynamic> args) {
  final List<int> frame = (args['frame'] as List).cast<int>();
  final int win = args['win'] as int;
  final int fs = args['fs'] as int;

  // 去 DC + Hann
  final mean = frame.fold<double>(0, (s, v) => s + v) / frame.length;
  final hann = List<double>.generate(
    win,
    (i) => 0.5 * (1 - math.cos(2 * math.pi * i / (win - 1))),
  );
  final x = List<double>.generate(
    win,
    (i) => hann[i] * ((frame[i] - mean) / 32768.0),
  );

  // 能量太低 → 視為靜音
  final energy = x.fold<double>(0, (s, v) => s + v * v) / win;
  if (energy < 1e-6) return 0.0;

  // FFT → 幅度
  final mag = _fftMag(x);

  // 搜尋 50..1500 Hz（先放寬，確認有值；之後可縮回 70..420 以專注吉他）
  int binLow = (50 * win / fs).floor();
  int binHigh = (1500 * win / fs).ceil();
  if (binLow < 1) binLow = 1;
  if (binHigh > mag.length - 2) binHigh = mag.length - 2;

  int p = binLow;
  double maxv = mag[binLow];
  for (int i = binLow + 1; i <= binHigh; i++) {
    if (mag[i] > maxv) {
      maxv = mag[i];
      p = i;
    }
  }

  // 拋物線插值微調
  final y0 = mag[p - 1], y1 = mag[p], y2 = mag[p + 1];
  final denom = (y0 - 2 * y1 + y2);
  final delta = denom.abs() < 1e-12 ? 0.0 : 0.5 * (y0 - y2) / denom;
  final freq = (p + delta) * fs / win;

  return freq.isFinite ? freq : 0.0;
}

// ===== 實作 FFT（實數輸入 → 0..N/2 幅度）=====
List<double> _fftMag(List<double> x) {
  final n = x.length;
  final re = List<double>.from(x);
  final im = List<double>.filled(n, 0);
  _fftInPlace(re, im);
  final half = n ~/ 2;
  return List<double>.generate(half, (i) {
    final a = re[i], b = im[i];
    return math.sqrt(a * a + b * b);
  });
}

void _fftInPlace(List<double> re, List<double> im) {
  final n = re.length;
  int j = 0;
  for (int i = 0; i < n; i++) {
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
    int m = n >> 1;
    while (j >= m && m >= 1) {
      j -= m;
      m >>= 1;
    }
    j += m;
  }
  for (int len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wlenCos = math.cos(ang), wlenSin = math.sin(ang);
    for (int i = 0; i < n; i += len) {
      double wCos = 1, wSin = 0;
      for (int k = 0; k < len ~/ 2; k++) {
        final uR = re[i + k], uI = im[i + k];
        final vR = re[i + k + len ~/ 2] * wCos - im[i + k + len ~/ 2] * wSin;
        final vI = re[i + k + len ~/ 2] * wSin + im[i + k + len ~/ 2] * wCos;
        re[i + k] = uR + vR;
        im[i + k] = uI + vI;
        re[i + k + len ~/ 2] = uR - vR;
        im[i + k + len ~/ 2] = uI - vI;
        final nwCos = wCos * wlenCos - wSin * wlenSin;
        final nwSin = wCos * wlenSin + wSin * wlenCos;
        wCos = nwCos;
        wSin = nwSin;
      }
    }
  }
}
