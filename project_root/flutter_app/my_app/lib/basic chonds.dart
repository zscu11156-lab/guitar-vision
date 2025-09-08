// lib/basic_chords.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';
import 'api.dart';

class BasicChordsPage extends StatelessWidget {
  const BasicChordsPage({super.key});

  // 你要挑戰的和弦清單（可自行調整）
  static const List<String> basicChords = [
    'Am','Am7','B','Bm','C','Cadd9','D','D7_F#','Dsus4','Em','Em7','G',
  ];

  // 倒數秒數（只在第一題） & 每題作答時間（秒）
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
            // 內容
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
                        Text('只要任一瞬間辨識到目標和弦就算對，立刻進下一題', style: TextStyle(color: Colors.white, fontSize: 18)),
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

            // 右上設定
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

      // BottomBar 導覽列（黑底）
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
            // Home
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
            // microphone -> tuner
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
            // history -> chordchart
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
            // Member
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

/// 單回合作答紀錄
class AttemptLog {
  final String chord;
  final bool success;
  final double spentSec; // 成功＝耗時秒；未完成＝整段作答時長
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

/// 挑戰頁：第一題倒數 → 每題 10 秒 → 任一瞬間命中即過關
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
  // 可調參數（單幀即過關模式：不需連擊、不看信心分數）
  static const Duration _inferInterval = Duration(milliseconds: 600);

  // 狀態
  late int _countdownLeft;
  late int _playLeft;
  bool _inCountdown = true; // 只用在第一題
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
  bool _advancing = false; // 防重入：成功換題時使用

  final List<AttemptLog> _history = [];

  @override
  void initState() {
  super.initState();
  _countdownLeft = widget.countdownSec; // 先給值，避免第一次 build 讀到未初始化
  _initCamera().then((_) => _startCountdown());
}

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playTimer?.cancel();
    _inferTimer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  // 取用前鏡頭（找不到則退而求其次）
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
    _inCountdown = true; // 僅第一題會用到
    _loggedThisRound = false;
    _countdownLeft = widget.countdownSec;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _countdownLeft--;
        if (_countdownLeft <= 0) {
          t.cancel();
          _startPlay(); // 第一題開始
        }
      });
    });
  }

  // 啟動一題（不倒數）：選新和弦、重設 10 秒、重開推論
  void _startPlay() {
    _inCountdown = false; // 後續題目都不會再倒數
    _targetChord = widget.chords[Random().nextInt(widget.chords.length)];
    _playLeft = widget.playDurationSec;
    _success = false;
    _timeToSuccess = null;
    _lastPredLabel = null;
    _lastPredConf = null;
    _loggedThisRound = false;
    _playStartAt = DateTime.now();
    _advancing = false;

    // 重新啟動倒數計時（每題 10 秒）
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _playLeft--;
        if (_playLeft <= 0) {
          t.cancel();
          _stopInfer();
          _success = false; // 逾時未完成
          _showFailOverlay(); // 顯示未完成頁（暫不跳轉學習）
        }
      });
    });

    // 重新啟動推論取樣
    _startInfer();
  }

  void _startInfer() {
    if (!_cameraReady || _cam == null) return;
    _inferTimer?.cancel();
    _inferTimer = Timer.periodic(_inferInterval, (_) => _snapAndPredict());
  }

  void _stopInfer() {
    _inferTimer?.cancel();
    _inferTimer = null;
  }

  Future<void> _snapAndPredict() async {
    if (!mounted || _cam == null || !_cameraReady) return;
    if (_snapBusy || _predictBusy || _advancing) return;

    try {
      _snapBusy = true;
      final xfile = await _cam!.takePicture(); // 拍攝 JPEG
      final bytes = await xfile.readAsBytes();
      _snapBusy = false;

      _predictBusy = true;
      final pred = await _predictWithTarget(bytes, _targetChord ?? '');
      _predictBusy = false;

      if (!mounted || pred == null) return;

      final predLabelNorm = _normalize(pred.label);
      final targetNorm = _normalize(_targetChord ?? '');

      // DEBUG：看正規化後的比對內容
      debugPrint('targetNorm=$targetNorm predNorm=$predLabelNorm raw="${pred.label}" conf=${pred.confidence}');

      // 單幀即過關：只要標籤相同或後端回傳 is_correct，就視為命中（不看信心分數）
      final isHit = (pred.isCorrect ?? false) || (predLabelNorm == targetNorm);

      setState(() {
        _lastPredLabel = pred.label;
        _lastPredConf = pred.confidence;
      });

      if (isHit) {
        // 成功：紀錄後直接切到下一題（不倒數、不彈面板）
        _advancing = true;
        _stopInfer();
        _playTimer?.cancel();
        _success = true;
        if (_playStartAt != null) {
          _timeToSuccess = DateTime.now().difference(_playStartAt!);
        }
        _logThisRound(successConf: pred.confidence);

        // 立即換題（會重設 10 秒、重開推論）
        _startPlay();
      }
    } catch (e) {
      _snapBusy = false;
      _predictBusy = false;
      debugPrint('推論錯誤: $e');
    }
  }

  // 後端對接（優先用帶 target 的 API；失敗退回 predictBytes）
  Future<_Pred?> _predictWithTarget(Uint8List jpgBytes, String targetChord) async {
    try {
      final r = await Api.predictWithTarget(jpgBytes, targetChord);
      return _Pred(
        label: (r['label'] as String?) ?? '',
        confidence: (r['confidence'] as num?)?.toDouble(),
        isCorrect: r['is_correct'] as bool?,
      );
    } catch (_) {
      try {
        final r2 = await Api.predictBytes(jpgBytes);
        final lbl = (r2['label'] as String?) ?? '';
        final conf = (r2['confidence'] as num?)?.toDouble();
        final ok = _normalize(lbl) == _normalize(targetChord);
        return _Pred(label: lbl, confidence: conf, isCorrect: ok);
      } catch (e) {
        debugPrint('predict fallback 失敗: $e');
        return null;
      }
    }
  }

  // —— 強化版正規化 —— //
  // 1) 全形-->半形、大小寫統一  2) ♯/＃ -> #、♭ -> b
  // 3) 去掉所有空白(含NBSP)、零寬、變體選擇符  4) 移除 _, -, /, \ 等分隔符
  String _normalize(String s) {
    if (s.isEmpty) return '';
    final buf = StringBuffer();
    for (final cp in s.runes) {
      int c = cp;
      // 全形 ASCII -> 半形
      if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0;
      // 特殊 dash 類統一成 '-'
      if (c == 0x2212 || c == 0x2013 || c == 0x2014) c = 0x2D;
      // NBSP -> space；去掉零寬/變體選擇符
      if (c == 0x00A0) c = 0x20;
      if (c == 0x200B || c == 0x200C || c == 0x200D || c == 0xFE0F) continue;
      // ♯/＃ -> #；♭ -> b
      if (c == 0x266F || c == 0xFF03) c = 0x23; // '#'
      if (c == 0x266D) c = 0x62; // 'b'
      buf.writeCharCode(c);
    }
    final t = buf.toString().toUpperCase();
    // 移除空白、底線、斜線、連字號、反斜線、Tab、CR等
    return t.replaceAll(RegExp(r'[\s_\-\/\\\t\r\n]+'), '');
  }

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

  // 逾時：顯示「未完成」頁（之後可改為導向和弦學習）
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
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
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
                      Navigator.pop(context);       // 關掉失敗面板
                      Navigator.pop(context);       // 離開挑戰
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
                      Navigator.pop(context); // 關掉失敗面板
                      _startPlay();           // 直接下一題（不倒數）
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
              // 前鏡頭做水平鏡像，視覺更直覺（不影響送到後端的影像）
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
          IconButton(
            onPressed: _openHistorySheet,
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: '查看紀錄',
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
                        '辨識：$_lastPredLabel'
                        '${_lastPredConf != null ? ' (${_lastPredConf!.toStringAsFixed(2)})' : ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        // 手動結束：當作逾時處理（跳未完成頁）
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
  _Pred({required this.label, this.confidence, this.isCorrect});
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
