// lib/tuner_engine.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const _mic = EventChannel('gv.tuner/audioStream');

// === 參數（可微調） ===
const int    WIN_SAMPLES         = 2048;   // ≈46ms @44.1k
const int    HOP_SAMPLES         = 1024;   // 50% overlap
const double FMIN                = 40.0;   // 搜尋頻帶
const double FMAX                = 900.0;
const int    CENT_BUF            = 7;      // 中位數濾波窗口 (幀)
const int    LOCK_NEED_FRAMES    = 5;      // 上鎖需要連續穩定幀數
const int    UNLOCK_BAD_FRAMES   = 4;      // 解鎖需要連續不穩幀數
const int    HOLD_MUTE_FRAMES    = 8;      // 沒音時維持上鎖的保留幀數
const double LOCK_TOL_CENTS      = 35.0;   // 上鎖容忍 (中位數距離)
const double LOCK_MAD_CENTS      = 12.0;   // 上鎖容忍 (MAD)
const double UNLOCK_TOL_CENTS    = 60.0;   // 解鎖門檻
const double UNLOCK_MAD_CENTS    = 20.0;   // 解鎖門檻
const double YIN_THRES_STRICT    = 0.10;   // YIN 門檻（越小越嚴）
const double YIN_ACCEPT          = 0.20;   // 接受 YIN 結果的上限
const double HPS_PROM_DB         = 8.0;    // HPS 顯著度門檻 (dB)
const double RMS_MIN_ABS         = 0.0008; // 絕對 RMS 下限
const int    NO_INPUT_MS         = 1500;   // 判定無音輸入的毫秒數

// 標準調弦（Hz）
const STANDARD_TUNING = <String, double>{
  "E2": 82.41, "A2": 110.00, "D3": 146.83,
  "G3": 196.00, "B3": 246.94, "E4": 329.63,
};

const STRING_HINT = <String, String>{
  "E2": "第六弦（低音E）", "A2": "第五弦（A）", "D3": "第四弦（D）",
  "G3": "第三弦（G）", "B3": "第二弦（B）", "E4": "第一弦（高音E）",
};

double _log2(num x) => math.log(x) / math.ln2;

class TunerState {
  final double freq;      // 顯示頻率 (Hz)
  final String note;      // 顯示的弦名（Note-Lock 後更穩）
  final double diffHz;    // 與標準差值（Hz）
  final double diffCents; // 與標準差值（cents）
  final String hint;
  final String advice;
  const TunerState({
    this.freq = 0, this.note = '', this.diffHz = 0, this.diffCents = 0,
    this.hint = '', this.advice = '—',
  });
  static const empty = TunerState();
}

class TunerEngine {
  final _out = StreamController<TunerState>.broadcast();
  Stream<TunerState> get stream => _out.stream;

  final int _fs = 44100;
  final List<int> _pcm = [];
  StreamSubscription<dynamic>? _sub;
  Timer? _tick, _reconnect;
  bool _busy = false;

  // 動態噪聲 & 無輸入偵測
  double _noiseRms = 0.001;
  final double _noiseAlpha = 0.04;
  bool _voiced = false;
  DateTime _lastPcmAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool get _noInput =>
      DateTime.now().difference(_lastPcmAt).inMilliseconds > NO_INPUT_MS;

  // 頻率與 cents 的平滑/穩定機制
  double _freqEma = 0;
  final double _emaAlpha = 0.35;
  final List<double> _centWindow = [];
  int _stableCount = 0;
  int _unstableCount = 0;
  int _muteHold = 0;

  // Note-Lock 狀態
  String _lockNote = '';
  double _lockRef = 0;

  // 靈敏度（越大越容易通過；這版走穩定 → 保守）
  double sensitivity = 0.75;

  void start() {
    _sub ??= _mic.receiveBroadcastStream().listen(
      _onBytes,
      onError: (_) => _handleStreamEnd(),
      onDone: _handleStreamEnd,
      cancelOnError: false,
    );

    // 與 hop 對齊（步幅一致）
    final hopMs = (HOP_SAMPLES * 1000 / _fs).round();
    _tick ??= Timer.periodic(Duration(milliseconds: hopMs), (_) => _processOnce());
  }

  Future<void> stop() async {
    await _sub?.cancel(); _sub = null;
    _tick?.cancel(); _tick = null;
    _reconnect?.cancel(); _reconnect = null;
    _pcm.clear();
    _centWindow.clear();
    _stableCount = _unstableCount = _muteHold = 0;
  }

  void dispose() { stop(); _out.close(); }

  void _handleStreamEnd([dynamic _]) {
    _sub?.cancel(); _sub = null;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(milliseconds: 700), () {
      if (_sub == null) start();
    });
  }

  void _onBytes(dynamic event) {
    if (event is! Uint8List || event.isEmpty) return;
    _lastPcmAt = DateTime.now();
    final bd = event.buffer.asByteData(event.offsetInBytes, event.lengthInBytes);
    for (int i = 0; i + 1 < bd.lengthInBytes; i += 2) {
      _pcm.add(bd.getInt16(i, Endian.little));
    }
    // 安全上限：保留約 2 秒的原始音，避免記憶體累積
    const int _pcmCap = 44100 * 2;
    if (_pcm.length > _pcmCap) {
      _pcm.removeRange(0, _pcm.length - _pcmCap);
    }
  }

  Future<void> _processOnce() async {
    if (_busy) return;

    if (_noInput) {
      _emit(const TunerState(freq: 0, advice: '未收到麥克風音訊，請確認權限/裝置設定'));
      _muteHold = (_lockNote.isNotEmpty)
          ? (_muteHold + 1).clamp(0, HOLD_MUTE_FRAMES)
          : 0;
      if (_muteHold >= HOLD_MUTE_FRAMES) _unlock();
      return;
    }
    if (_pcm.length < WIN_SAMPLES) return;

    final frame = _pcm.take(WIN_SAMPLES).toList();
    _pcm.removeRange(0, HOP_SAMPLES);

    // === RMS 動態門檻（保守）===（先轉 double，避免 s*s 整數溢位）
    double sum2 = 0;
    for (final s in frame) {
      final ds = s.toDouble();
      sum2 += ds * ds;
    }
    final rms = math.sqrt(sum2 / frame.length) / 32768.0;

    if (!_voiced || rms < _noiseRms * 1.2) {
      _noiseRms = (1 - _noiseAlpha) * _noiseRms + _noiseAlpha * rms;
    }

    final double openMul = 3.0 - 2.0 * sensitivity; // 1..3
    final double closeMul = openMul * 0.7;

    // 沒開門：需要超過相對噪聲與絕對下限
    if (!_voiced && (rms < _noiseRms * openMul || rms < RMS_MIN_ABS)) {
      _emit(const TunerState(freq: 0));
      return;
    }

    // 已開門：掉太低才關
    if (_voiced && rms < _noiseRms * closeMul) {
      _voiced = false;
    }

    _busy = true;
    try {
      // 1) YIN（主）
      final yin = await compute(_yinPitch, {
        'frame': frame, 'fs': _fs,
        'fmin': FMIN, 'fmax': FMAX, 'thres': YIN_THRES_STRICT,
      });
      double f = yin.freq;
      double q = yin.q; // 0..1，越小越好

      // 2) YIN 品質不佳 → HPS 備援
      if (!(f > 0) || q > YIN_ACCEPT) {
        final hps = await compute(_hpsPitchProm, {
          'frame': frame, 'fs': _fs, 'win': WIN_SAMPLES,
          'fmin': FMIN, 'fmax': FMAX,
        });
        if (hps.freq > 0 && hps.promDb >= HPS_PROM_DB) {
          f = hps.freq; q = 0.3;
        }
      }

      if (!(f > 0)) {
        _voiced = false;
        _emit(const TunerState(freq: 0));
        return;
      }

      // 3) 倍音修正（折回 2/3/4 倍音）
      f = _correctToStringHarmonics(f);

      // 4) 比對最接近的弦 → 計算 cents 與穩定性
      final nearest = _nearestString(f);
      final ref = STANDARD_TUNING[nearest]!;
      double cents = 1200 * _log2(f / ref);

      // 推入中位數窗口
      _pushCents(cents);
      final med = _median(_centWindow);
      final mad = _mad(_centWindow, med);

      final bool stableNow = med.abs() <= LOCK_TOL_CENTS && mad <= LOCK_MAD_CENTS;

      if (_lockNote.isEmpty) {
        // 還沒上鎖 → 計數穩定幀
        _stableCount = stableNow ? (_stableCount + 1) : 0;
        if (_stableCount >= LOCK_NEED_FRAMES) {
          _lock(nearest, ref);
          cents = med; // 使用中位數較穩
        } else {
          // 未上鎖：輸出暫時值，但也做平滑
          final fSmoothed = (_freqEma == 0)
              ? f
              : (_emaAlpha * f + (1 - _emaAlpha) * _freqEma);
          _freqEma = fSmoothed;
          _emit(_makeState(fSmoothed, nearest, ref));
          return;
        }
      } else {
        // 已上鎖：只允許在鎖定弦附近活動
        final double centsToLock = 1200 * _log2(f / _lockRef);
        final bool nearLock = centsToLock.abs() <= UNLOCK_TOL_CENTS;
        final bool stableLock = mad <= UNLOCK_MAD_CENTS;

        if (!nearLock || !stableLock) {
          _unstableCount++;
          if (_unstableCount >= UNLOCK_BAD_FRAMES) _unlock();
        } else {
          _unstableCount = 0;
        }
        cents = centsToLock; // 以鎖定弦為主顯示
      }

      // 5) 最終平滑（Hz 域），再輸出
      final fShow = (_freqEma == 0)
          ? f
          : (_emaAlpha * f + (1 - _emaAlpha) * _freqEma);
      _freqEma = fShow;
      _voiced = true;

      final showNote = _lockNote.isNotEmpty ? _lockNote : nearest;
      final showRef  = _lockNote.isNotEmpty ? _lockRef  : ref;

      _emit(_makeState(fShow, showNote, showRef, overrideCents: cents));
    } finally {
      _busy = false;
    }
  }

  void _pushCents(double c) {
    _centWindow.add(c);
    if (_centWindow.length > CENT_BUF) _centWindow.removeAt(0);
  }

  void _lock(String note, double ref) {
    _lockNote = note;
    _lockRef  = ref;
    _unstableCount = 0;
    _muteHold = 0;
  }

  void _unlock() {
    _lockNote = '';
    _lockRef = 0;
    _stableCount = 0;
    _unstableCount = 0;
    _muteHold = 0;
    _centWindow.clear();
  }

  String _nearestString(double f) {
    String bestKey = 'E2';
    double bestC = 1e9;
    STANDARD_TUNING.forEach((k, v) {
      final c = (1200 * _log2(f / v)).abs();
      if (c < bestC) { bestC = c; bestKey = k; }
    });
    return bestKey;
  }

  // 把 2/3/4 倍音折回基音（以最近弦為參考）
  double _correctToStringHarmonics(double f) {
    final k = _nearestString(f);
    final ref = STANDARD_TUNING[k]!;
    double bestFreq = f;
    double bestCents = (1200 * _log2(f / ref)).abs();
    for (final m in [2, 3, 4]) {
      final fm = f / m;
      final cm = (1200 * _log2(fm / ref)).abs();
      if (cm + 8 < bestCents) { bestCents = cm; bestFreq = fm; }
    }
    // 如果低於該弦太多（>900c），可能是基音抓太低 → 嘗試 *2 折回
    if ((1200 * _log2(bestFreq / ref)).abs() > 900) {
      final f2 = bestFreq * 2;
      final c2 = (1200 * _log2(f2 / ref)).abs();
      if (c2 < bestCents) bestFreq = f2;
    }
    return bestFreq;
  }

  TunerState _makeState(double fShow, String note, double ref, {double? overrideCents}) {
    final diffHz = (fShow > 0 && ref > 0) ? (fShow - ref) : 0.0;
    final cents  = overrideCents ?? ((fShow > 0 && ref > 0) ? 1200 * _log2(fShow / ref) : 0.0);
    String advice;
    if (note.isEmpty || fShow == 0) {
      advice = '—';
    } else if (cents.abs() <= 5) {
      advice = '音準正確（±5 cents 內）';
    } else if (cents > 0) {
      advice = '音高偏高，請鬆一點（降低音高）';
    } else {
      advice = '音高偏低，請轉緊一點（提高音高）';
    }
    return TunerState(
      freq: fShow.isFinite ? fShow : 0,
      note: note,
      diffHz: diffHz.isFinite ? diffHz : 0,
      diffCents: cents.isFinite ? cents : 0,
      hint: STRING_HINT[note] ?? '',
      advice: advice,
    );
  }

  void _emit(TunerState s) {
    if (!_out.isClosed) _out.add(s);
  }
}

/* ===================== YIN（主算法） ===================== */
class _YinResult { final double freq, q; const _YinResult(this.freq, this.q); }

_YinResult _yinPitch(Map<String, dynamic> args) {
  final List<int> frame = (args['frame'] as List).cast<int>();
  final int fs = args['fs'] as int;
  final double fmin = args['fmin'] as double;
  final double fmax = args['fmax'] as double;
  final double thres = args['thres'] as double;

  final n = frame.length;
  double mean = 0; for (final v in frame) mean += v; mean /= n;
  final x = List<double>.generate(n, (i) => (frame[i] - mean) / 32768.0);

  int tauMin = (fs / fmax).floor();
  int tauMax = (fs / fmin).ceil();
  if (tauMax >= n - 1) tauMax = n - 2;
  if (tauMin < 2) tauMin = 2;
  if (tauMin >= tauMax) return const _YinResult(0.0, 1.0);

  final d = List<double>.filled(tauMax + 1, 0);
  for (int tau = 1; tau <= tauMax; tau++) {
    double sum = 0;
    for (int i = 0; i + tau < n; i++) {
      final diff = x[i] - x[i + tau];
      sum += diff * diff;
    }
    d[tau] = sum;
  }

  final cmnd = List<double>.filled(tauMax + 1, 0);
  double running = 0; cmnd[0] = 1.0;
  for (int tau = 1; tau <= tauMax; tau++) {
    running += d[tau];
    cmnd[tau] = d[tau] * tau / (running + 1e-12);
  }

  int tau = -1;
  for (int t = tauMin + 1; t < tauMax - 1; t++) {
    if (cmnd[t] < thres && cmnd[t] <= cmnd[t - 1] && cmnd[t] <= cmnd[t + 1]) {
      tau = t; break;
    }
  }
  if (tau == -1) {
    double minv = double.infinity; int argmin = tauMin;
    for (int t = tauMin; t <= tauMax; t++) {
      if (cmnd[t] < minv) { minv = cmnd[t]; argmin = t; }
    }
    tau = argmin;
  }

  final t0 = (tau > 1) ? cmnd[tau - 1] : cmnd[tau];
  final t1 = cmnd[tau];
  final t2 = (tau + 1 <= tauMax) ? cmnd[tau + 1] : cmnd[tau];
  final denom = (t0 + t2 - 2 * t1);
  final delta = denom.abs() < 1e-12 ? 0.0 : 0.5 * (t0 - t2) / denom;
  final tauRef = (tau + delta).clamp(tauMin.toDouble(), tauMax.toDouble());

  final freq = fs / tauRef;
  final q = cmnd[tau].clamp(0.0, 1.0);
  return _YinResult(freq.isFinite ? freq : 0.0, q.isFinite ? q : 1.0);
}

/* ===================== HPS 備援 + 顯著度 ===================== */
class _FreqProm { final double freq, promDb; const _FreqProm(this.freq, this.promDb); }

_FreqProm _hpsPitchProm(Map<String, dynamic> args) {
  final List<int> frame = (args['frame'] as List).cast<int>();
  final int fs = args['fs'] as int;
  final int win = args['win'] as int;
  final double fmin = args['fmin'] as double;
  final double fmax = args['fmax'] as double;

  double mean = 0; for (final v in frame) mean += v; mean /= frame.length;
  final hann = List<double>.generate(
    win, (i) => 0.5 * (1 - math.cos(2 * math.pi * i / (win - 1))),
  );
  final x = List<double>.generate(
    win, (i) => hann[i] * ((frame[i] - mean) / 32768.0),
  );

  double energy = 0; for (final v in x) { energy += v * v; }
  energy /= win;
  if (energy < 5e-8) return const _FreqProm(0.0, 0.0);

  double maxAbs = 0; for (final v in x) { final a = v.abs(); if (a > maxAbs) maxAbs = a; }
  if (maxAbs > 1e-9) { for (int i = 0; i < x.length; i++) x[i] /= maxAbs; }

  final mag = _fftMag(x);

  void notch(double baseHz) {
    for (int k = 1; k <= 8; k++) {
      final hz = baseHz * k;
      final idx = (hz * win / fs).round();
      if (idx >= 1 && idx + 1 < mag.length) {
        mag[idx] = 0; mag[idx - 1] = 0; mag[idx + 1] = 0;
      }
    }
  }
  notch(50); notch(60);

  final nBins = mag.length;
  final hps = List<double>.from(mag);
  for (int factor = 2; factor <= 3; factor++) {
    for (int i = 0; i < nBins ~/ factor; i++) {
      hps[i] *= mag[i * factor];
    }
    for (int i = nBins ~/ factor; i < nBins; i++) {
      hps[i] = 0;
    }
  }

  int binLow = (fmin * win / fs).floor();
  int binHigh = (fmax * win / fs).ceil();
  if (binLow < 2) binLow = 2;
  if (binHigh > hps.length - 3) binHigh = hps.length - 3;

  int p = binLow; double maxv = hps[binLow];
  double sum = 0; int cnt = 0;
  for (int i = binLow; i <= binHigh; i++) {
    final v = hps[i];
    if (v > maxv) { maxv = v; p = i; }
    sum += v; cnt++;
  }

  final noiseSum = sum - (hps[p - 1] + hps[p] + hps[p + 1]);
  final noiseCnt = (cnt - 3).clamp(1, 1 << 30);
  double noiseAvg = noiseSum / noiseCnt;
  if (noiseAvg <= 1e-12) noiseAvg = 1e-12;
  final promDb = 20 * (math.log(maxv / noiseAvg) / math.ln10);

  final y0 = hps[p - 1], y1 = hps[p], y2 = hps[p + 1];
  final denom = (y0 - 2 * y1 + y2);
  final delta = denom.abs() < 1e-12 ? 0.0 : 0.5 * (y0 - y2) / denom;
  final freq = (p + delta) * fs / win;

  return _FreqProm((freq.isFinite && freq > 0) ? freq : 0.0,
                   promDb.isFinite ? promDb : 0.0);
}

/* ============================ FFT & 統計 ============================ */
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
      final tr = re[i]; re[i] = re[j]; re[j] = tr;
      final ti = im[i]; im[i] = im[j]; im[j] = ti;
    }
    int m = n >> 1;
    while (j >= m && m >= 1) { j -= m; m >>= 1; }
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
        re[i + k] = uR + vR;       im[i + k] = uI + vI;
        re[i + k + len ~/ 2] = uR - vR; im[i + k + len ~/ 2] = uI - vI;
        final nwCos = wCos * wlenCos - wSin * wlenSin;
        final nwSin = wCos * wlenSin + wSin * wlenCos;
        wCos = nwCos; wSin = nwSin;
      }
    }
  }
}

double _median(List<double> xs) {
  if (xs.isEmpty) return 0;
  final a = List<double>.from(xs)..sort();
  final m = a.length >> 1;
  return (a.length % 2 == 1) ? a[m] : 0.5 * (a[m - 1] + a[m]);
}

double _mad(List<double> xs, double med) {
  if (xs.isEmpty) return 0;
  final dev = xs.map((v) => (v - med).abs()).toList()..sort();
  final m = dev.length >> 1;
  return (dev.length % 2 == 1) ? dev[m] : 0.5 * (dev[m - 1] + dev[m]);
}
