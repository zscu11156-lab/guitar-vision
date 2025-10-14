// lib/basic_chords.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// 音訊
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

// 影像 bytes 處理（用於前鏡頭水平反轉）
import 'package:image/image.dart' as img;

import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';
import 'api.dart';

class BasicChordsPage extends StatelessWidget {
  const BasicChordsPage({super.key});

  static const List<String> basicChords = [
    'Am','Am7','B','Bm','C','Cadd9','D','D7_F#','Dsus4','Em','Em7','G',
  ];

  static const int countdownSec = 3;
  static const int playDurationSec = 10;

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      '挑戰說明',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'LaBelleAurore',
                        fontSize: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                  const Center(
                    child: Column(
                      children: [
                        Text('挑戰開始後', style: TextStyle(color: Colors.white, fontSize: 18)),
                        SizedBox(height: 6),
                        Text('會先倒數 3 秒（只有第一題）', style: TextStyle(color: Colors.white, fontSize: 18)),
                        SizedBox(height: 6),
                        Text('之後每題隨機一個和弦，各有 10 秒', style: TextStyle(color: Colors.white, fontSize: 18)),
                        SizedBox(height: 6),
                        Text('音訊或影像任一命中目標和弦就過關', style: TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BasicChordsChallengePage(
                              chords: basicChords,
                              countdownSec: countdownSec,
                              playDurationSec: playDurationSec,
                            ),
                          ),
                        );
                      },
                      child: const Text('開始挑戰'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
                child: Image.asset('assets/images/Setting.png', width: 50),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
            _NavItem(
              img: 'assets/images/home.png',
              size: 50,
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                  );
                }
              },
            ),
            _NavItem(
              img: 'assets/images/tuner.png',
              size: navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GvTunerPage()),
                );
              },
            ),
            _NavItem(
              img: 'assets/images/chordchart.png',
              size: navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChordChart()),
                );
              },
            ),
            _NavItem(
              img: 'assets/images/member.png',
              size: navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemberPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AttemptLog {
  final String chord;
  final bool success;
  final double spentSec;
  final DateTime when;
  final double? successConfidence;

  AttemptLog({
    required this.chord,
    required this.success,
    required this.spentSec,
    required this.when,
    this.successConfidence,
  });
}

class BasicChordsChallengePage extends StatefulWidget {
  final List<String> chords;
  final int countdownSec;
  final int playDurationSec;

  const BasicChordsChallengePage({
    super.key,
    required this.chords,
    required this.countdownSec,
    required this.playDurationSec,
  });

  @override
  State<BasicChordsChallengePage> createState() =>
      _BasicChordsChallengePageState();
}

class _BasicChordsChallengePageState extends State<BasicChordsChallengePage> {
  // ——— 把頻率略加快，讓後端 (HOLD_FRAMES=3) 比較容易連續命中 ———
  static const Duration _inferInterval = Duration(milliseconds: 350);

  // ===== 狀態 =====
  late int _countdownLeft;
  late int _playLeft;
  bool _inCountdown = true;
  String? _targetChord;

  Timer? _countdownTimer;
  Timer? _playTimer;

  CameraController? _cam;
  bool _cameraReady = false;
  Timer? _inferTimer;
  bool _snapBusy = false;
  bool _predictBusy = false;

  String? _lastPredLabel;
  double? _lastPredConf;

  DateTime? _playStartAt;
  Duration? _timeToSuccess;
  bool _success = false;
  bool _loggedThisRound = false;
  bool _advancing = false;

  final List<AttemptLog> _history = [];

  // ===== 音訊狀態 / 緩衝 =====
  final FlutterAudioCapture _cap = FlutterAudioCapture();
  static const int _sr = 44100;
  static const int _winBytes = _sr * 2; // 1秒 mono 16-bit
  Timer? _audioTimer;
  bool _audioBusy = false;

  final List<int> _ring = <int>[];
  String? _lastAudioVote;
  double? _lastEnergy;
  double? _lastAudioConf;

  // ===== 門檻（統一 0.30） =====
  static const double _audioLooseConf  = 0.30;
  static const double _VISION_CONF_PASS = 0.30;
  static const double _VISION_TOPK_PASS = 0.30;

  @override
  void initState() {
    super.initState();
    _countdownLeft = widget.countdownSec;
    _initCamera().then((_) => _startCountdown());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playTimer?.cancel();
    _inferTimer?.cancel();
    _stopMic();
    _cam?.dispose();
    super.dispose();
  }

  // ====== Camera ======
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      CameraDescription? front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.isNotEmpty ? cams.first : throw Exception('No camera'),
      );
      _cam = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cam!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraReady = false);
      _toast('相機初始化失敗：$e');
    }
  }

  void _startCountdown() {
    _inCountdown = true;
    _loggedThisRound = false;
    _countdownLeft = widget.countdownSec;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _countdownLeft--;
        if (_countdownLeft <= 0) {
          t.cancel();
          _startPlay();
        }
      });
    });
  }

  // ====== 每題開始 ======
  void _startPlay() {
    _inCountdown = false;
    _targetChord = widget.chords[Random().nextInt(widget.chords.length)];
    _playLeft = widget.playDurationSec;
    _success = false;
    _timeToSuccess = null;
    _lastPredLabel = null;
    _lastPredConf = null;
    _loggedThisRound = false;
    _playStartAt = DateTime.now();
    _advancing = false;

    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _playLeft--;
        if (_playLeft <= 0) {
          t.cancel();
          _stopInfer();
          _success = false;
          _showFailOverlay();
        }
      });
    });

    _startInfer();

    // 啟動音訊串流
    () async { await _stopMic(); await _startMic(); }();
  }

  void _startInfer() {
    if (!_cameraReady || _cam == null) return;
    _inferTimer?.cancel();
    _inferTimer = Timer.periodic(_inferInterval, (_) => _snapAndPredict());
  }

  void _stopInfer() {
    _inferTimer?.cancel();
    _inferTimer = null;
    _stopMic();
  }

  // —— 前鏡頭：把要上傳的 JPEG 水平反轉（伺服器會以「正向」來看）——
  Uint8List _maybeMirrorJpeg(Uint8List bytes, bool mirror) {
    if (!mirror) return bytes;
    final im = img.decodeImage(bytes);
    if (im == null) return bytes;
    final flipped = img.flipHorizontal(im);
    return Uint8List.fromList(img.encodeJpg(flipped, quality: 85));
  }

  Future<void> _snapAndPredict() async {
    if (!mounted || _cam == null || !_cameraReady) return;
    if (_snapBusy || _predictBusy || _advancing) return;

    try {
      _snapBusy = true;
      final xfile = await _cam!.takePicture();
      var bytes = await xfile.readAsBytes();
      _snapBusy = false;

      // 若為前鏡頭，送出前先水平反轉
      final isFront = _cam!.description.lensDirection == CameraLensDirection.front;
      bytes = _maybeMirrorJpeg(bytes, isFront);

      _predictBusy = true;
      final pred = await _predictWithTarget(bytes, _targetChord ?? '');
      _predictBusy = false;

      if (!mounted || pred == null) return;

      final normLabel   = _normalize(pred.label);
      final normTarget  = _normalize(_targetChord ?? '');
      final targetCanon = _toFamily(normTarget);

      bool isHit = false;

      // 0) 若後端已判定連續幀成立 → 直接過關
      if (pred.scoreEvent == true) {
        isHit = true;
      }

      // 1) 後端多數決正確（is_correct_maj）或單幀 is_correct
      if (!isHit && (pred.isCorrectMaj == true)) isHit = true;
      if (!isHit && (pred.isCorrect == true))    isHit = true;

      // 2) 單幀/多數決 標籤與目標字串完全一致
      if (!isHit && normLabel == normTarget) isHit = true;
      if (!isHit && pred.majLabel != null && _normalize(pred.majLabel!) == normTarget) isHit = true;

      // 3) 同家族 + 信心達標（0.30）
      if (!isHit && _sameFamily(normLabel, normTarget) && (pred.confidence ?? 0) >= _VISION_CONF_PASS) {
        isHit = true;
      }
      if (!isHit && pred.majLabel != null) {
        if (_sameFamily(_normalize(pred.majLabel!), normTarget) &&
            (pred.majConfidence ?? 0) >= _VISION_CONF_PASS) {
          isHit = true;
        }
      }

      // 4) top-k 有目標家族且機率達標（0.30）
      if (!isHit && pred.topk != null && pred.topk!.isNotEmpty) {
        for (final e in pred.topk!.entries) {
          if (e.value >= _VISION_TOPK_PASS && _toFamily(e.key) == targetCanon) {
            isHit = true;
            break;
          }
        }
      }

      setState(() {
        _lastPredLabel = pred.majLabel ?? pred.label; // 顯示多數決結果優先
        _lastPredConf  = pred.majConfidence ?? pred.confidence;
      });

      if (isHit) {
        _onSuccess(by: 'vision', conf: pred.majConfidence ?? pred.confidence);
      }
    } catch (e) {
      _snapBusy = false;
      _predictBusy = false;
      debugPrint('推論錯誤: $e');
    }
  }

  // ====== Audio: flutter_audio_capture + /audio_chunk ======
  Future<void> _startMic() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _toast('麥克風權限被拒絕，改用影像判定');
      return;
    }

    await _cap.start(
      (dynamic obj) {
        final bytes = _toPCM16Bytes(obj);
        if (bytes.isEmpty) return;
        _ring.addAll(bytes);
        final maxKeep = _winBytes * 2; // 最多保留 2 秒
        if (_ring.length > maxKeep) {
          _ring.removeRange(0, _ring.length - maxKeep);
        }
      },
      (Object e) => debugPrint('audio_capture error: $e'),
      sampleRate: _sr,
      bufferSize: 4096,
    );

    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _pollAudio());
  }

  Future<void> _stopMic() async {
    try { await _cap.stop(); } catch (_) {}
    _audioTimer?.cancel();
    _audioTimer = null;
    _ring.clear();
  }

  Uint8List _toPCM16Bytes(dynamic obj) {
    if (obj is Float32List) {
      final out = Int16List(obj.length);
      for (var i = 0; i < obj.length; i++) {
        final s = (obj[i] * 32767.0).clamp(-32768.0, 32767.0).round();
        out[i] = s;
      }
      return Uint8List.view(out.buffer);
    } else if (obj is Float64List) {
      final out = Int16List(obj.length);
      for (var i = 0; i < obj.length; i++) {
        final s = (obj[i] * 32767.0).clamp(-32768.0, 32767.0).round();
        out[i] = s;
      }
      return Uint8List.view(out.buffer);
    } else if (obj is List) {
      final out = Int16List(obj.length);
      for (var i = 0; i < obj.length; i++) {
        final v = (obj[i] as num).toDouble();
        final s = (v * 32767.0).clamp(-32768.0, 32767.0).round();
        out[i] = s;
      }
      return Uint8List.view(out.buffer);
    }
    return Uint8List(0);
  }

  Future<void> _pollAudio() async {
    if (_audioBusy) return;
    if (_ring.length < _winBytes) return;
    try {
      _audioBusy = true;
      final start = _ring.length - _winBytes;
      final window = Uint8List.fromList(_ring.sublist(start));

      final r = await Api.audioChunk(window, sr: _sr);
      final vote = (r['vote'] as String?) ?? 'NC';
      final chord = (r['chord'] as String?) ?? 'NC';
      final energy = (r['energy'] as num?)?.toDouble();
      final conf = (r['conf'] as num?)?.toDouble();

      if (!mounted) return;
      setState(() {
        _lastAudioVote = vote;
        _lastEnergy = energy;
        _lastAudioConf = conf;
      });

      if (_targetChord != null) {
        final target = _targetChord!;

        // ① 多數決：同家族即可過關
        final hitByVoteFam = _sameFamily(vote, target);

        // ② 當前窗：同家族且 conf ≥ 0.30 也過關
        final hitByChordConfFam = _sameFamily(chord, target) &&
                                  (conf != null && conf >= _audioLooseConf);

        if (hitByVoteFam || hitByChordConfFam) {
          _onSuccess(by: hitByVoteFam ? 'audio(vote_fam)' : 'audio(conf_fam)', conf: conf);
        }
      }
    } catch (e) {
      debugPrint('audio_chunk error: $e');
    } finally {
      _audioBusy = false;
    }
  }

  // ====== 共用過關流程 ======
  void _onSuccess({required String by, double? conf}) {
    if (_advancing) return;
    _advancing = true;
    _stopInfer();                // 也會關 mic
    _playTimer?.cancel();
    _success = true;
    if (_playStartAt != null) {
      _timeToSuccess = DateTime.now().difference(_playStartAt!);
    }
    _logThisRound(successConf: conf);
    // 立即下一題
    _startPlay();
  }

  // ====== 後端對接（影像） ======
  Future<_Pred?> _predictWithTarget(Uint8List jpgBytes, String targetChord) async {
    try {
      final r = await Api.predictWithTarget(jpgBytes, targetChord);

      // 解析 topk: [{label: "...", prob: 0.xx}, ...]
      Map<String, double>? topk;
      final rawTopk = r['topk'];
      if (rawTopk is List) {
        topk = <String, double>{};
        for (final e in rawTopk) {
          if (e is Map) {
            final lbl = (e['label'] as String?) ?? '';
            final p = (e['prob'] as num?)?.toDouble() ?? 0.0;
            topk[_normalize(lbl)] = p;
          }
        }
      }

      return _Pred(
        label: (r['label'] as String?) ?? '',
        confidence: (r['confidence'] as num?)?.toDouble(),
        isCorrect: r['is_correct'] as bool?,
        // 新增：使用伺服器多數決與連續幀事件
        majLabel: (r['maj_label'] as String?),
        majConfidence: (r['maj_confidence'] as num?)?.toDouble(),
        isCorrectMaj: r['is_correct_maj'] as bool?,
        scoreEvent: (r['score_event'] as bool?) ?? false,
        topk: topk,
      );
    } catch (_) {
      // 後備：舊 API（無 target）
      try {
        final r2 = await Api.predictBytes(jpgBytes);
        final lbl = (r2['label'] as String?) ?? '';
        final conf = (r2['confidence'] as num?)?.toDouble();
        final ok = _normalize(lbl) == _normalize(targetChord);
        return _Pred(
          label: lbl,
          confidence: conf,
          isCorrect: ok,
          majLabel: null,
          majConfidence: null,
          isCorrectMaj: null,
          scoreEvent: false,
          topk: null,
        );
      } catch (e) {
        debugPrint('predict fallback 失敗: $e');
        return null;
      }
    }
  }

  // ====== Normalize & Family ======
  String _normalize(String s) {
    if (s.isEmpty) return '';
    final buf = StringBuffer();
    for (final cp in s.runes) {
      int c = cp;
      if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // 全形→半形
      if (c == 0x2212 || c == 0x2013 || c == 0x2014) c = 0x2D;
      if (c == 0x00A0) c = 0x20;
      if (c == 0x200B || c == 0x200C || c == 0x200D || c == 0xFE0F) continue;
      if (c == 0x266F || c == 0xFF03) c = 0x23; // ♯/＃ → '#'
      if (c == 0x266D) c = 0x62;                // ♭ → 'b'
      buf.writeCharCode(c);
    }
    final t = buf.toString().toUpperCase();
    return t.replaceAll(RegExp(r'[\s_\-\/\\\t\r\n]+'), '');
  }

  // 等價家族映射（key 使用 _normalize 後的字串）
  String _toFamily(String raw) {
    final s = _normalize(raw);
    switch (s) {
      // A 小調家族
      case 'AM':
      case 'AM7':
        return 'A*MIN';

      // C 大調家族
      case 'C':
      case 'CADD9':
        return 'C*MAJ';

      // D 家族（常見變化）
      case 'D':
      case 'DSUS4':
      case 'D7F#':
        return 'D*GEN';

      // E 小調家族
      case 'EM':
      case 'EM7':
        return 'E*MIN';

      // 單一和弦（沒有等價）
      case 'G':
        return 'G*';
      case 'B':
        return 'B*MAJ';
      case 'BM':
        return 'B*MIN';
    }
    return s; // 未定義則回傳自身
  }

  bool _sameFamily(String a, String b) => _toFamily(a) == _toFamily(b);

  void _logThisRound({double? successConf}) {
    if (_loggedThisRound) return;
    final chord = _targetChord ?? '-';
    final spent = _success
        ? (_timeToSuccess?.inMilliseconds ?? 0) / 1000.0
        : widget.playDurationSec.toDouble();
    _history.add(AttemptLog(
      chord: chord,
      success: _success,
      spentSec: spent,
      when: DateTime.now(),
      successConfidence: _success ? successConf : null,
    ));
    _loggedThisRound = true;
  }

  Future<void> _showFailOverlay() async {
    if (!mounted) return;
    _logThisRound();
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final target = _targetChord ?? '-';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('X',style:TextStyle( color: Colors.redAccent, fontSize:48)),
              const SizedBox(height: 12),
              const Text('未完成', style: TextStyle(color: Colors.white, fontSize: 22)),
              const SizedBox(height: 8),
              Text('目標和弦：$target', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('結束挑戰'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9D9D9),
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _startPlay();
                    },
                    child: const Text('下一題'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openHistorySheet,
                child: const Text('查看本次紀錄', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        if (_history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('尚無紀錄', style: TextStyle(color: Colors.white70)),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('本次挑戰紀錄', style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 12),
              ..._history.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.chord, style: const TextStyle(color: Colors.white)),
                    Text(
                      e.success
                          ? '完成 ${e.spentSec.toStringAsFixed(2)}s'
                          : '未完成',
                      style: TextStyle(color: e.success ? Colors.lightGreen : Colors.redAccent),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const big = TextStyle(color: Colors.white, fontFamily: 'ABeeZee', fontSize: 80);
    const normal = TextStyle(color: Colors.white, fontSize: 18);

    final preview = (!_cameraReady || _cam == null || !_cam!.value.isInitialized)
        ? const SizedBox(
            height: 220,
            child: Center(child: Text('相機尚未就緒', style: TextStyle(color: Colors.white54))),
          )
        : AspectRatio(
            aspectRatio: _cam!.value.previewSize!.width / _cam!.value.previewSize!.height,
            child: Builder(builder: (_) {
              final isFront = _cam!.description.lensDirection == CameraLensDirection.front;
              final pv = CameraPreview(_cam!);
              return isFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                      child: pv,
                    )
                  : pv;
            }),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Basic Chords 挑戰'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _openHistorySheet,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('查看紀錄', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _inCountdown
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('準備囉', style: normal),
                    const SizedBox(height: 16),
                    Text('$_countdownLeft', style: big),
                    const SizedBox(height: 24),
                    SizedBox(height: 220, child: preview),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 220, child: preview),
                    const SizedBox(height: 16),
                    const Text('請彈出畫面中的和弦', style: normal),
                    const SizedBox(height: 16),
                    Text(_targetChord ?? '-', style: big),
                    const SizedBox(height: 8),
                    Text('剩餘：$_playLeft 秒', style: normal),
                    const SizedBox(height: 8),
                    if (_lastPredLabel != null)
                      Text(
                        '影像：$_lastPredLabel'
                        '${_lastPredConf != null ? ' (${_lastPredConf!.toStringAsFixed(2)})' : ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (_lastAudioVote != null)
                      Text(
                        '音訊：$_lastAudioVote'
                        '${_lastAudioConf != null ? ' (${_lastAudioConf!.toStringAsFixed(2)})' : ''}'
                        '${_lastEnergy != null ? '  energy ${_lastEnergy!.toStringAsFixed(3)}' : ''}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.black87),
                      onPressed: () {
                        _stopInfer();
                        _playTimer?.cancel();
                        _success = false;
                        _showFailOverlay();
                      },
                      child: const Text('結束挑戰'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$k：', style: const TextStyle(color: Colors.white70)),
            Text(v, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
}

class _Pred {
  final String label;
  final double? confidence;
  final bool? isCorrect;
  final Map<String, double>? topk; // label(正規化) -> 機率

  // 伺服器多數決 / 連續幀
  final String? majLabel;
  final double? majConfidence;
  final bool? isCorrectMaj;
  final bool scoreEvent;

  _Pred({
    required this.label,
    this.confidence,
    this.isCorrect,
    this.topk,
    this.majLabel,
    this.majConfidence,
    this.isCorrectMaj,
    this.scoreEvent = false,
  });
}

// ────── 共用底部導覽列項目 ──────
class _NavItem extends StatelessWidget {
  final String img;
  final double size;
  final VoidCallback? onTap;
  const _NavItem({required this.img, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(child: Image.asset(img, width: size)),
        ),
      );
}
