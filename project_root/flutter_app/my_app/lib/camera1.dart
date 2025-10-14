import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img; // 用於校正方向/水平反轉
// 保持螢幕常亮
import 'package:wakelock_plus/wakelock_plus.dart';

// 呼叫後端 /predict
import 'api.dart';
// 新增：評分後導向和弦總表
import 'chordchart.dart';

/// ---- 和弦時間軸事件（頂層宣告；Dart 不支援巢狀 class）----
class _ChordEvt {
  final Duration start;
  final Duration end;
  final String chord;
  const _ChordEvt(this.start, this.end, this.chord);
}

class camera1 extends StatefulWidget {
  const camera1({super.key});

  @override
  State<camera1> createState() => _CameraQingtianPageState();
}

class _CameraQingtianPageState extends State<camera1> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;

  CameraController? _controller;
  bool _camReady = false;

  // ============ 即時和弦辨識狀態 ============
  Timer? _inferTimer;
  bool _inferBusy = false;
  static const int _win = 5; // 多數決視窗大小
  static const int _need = 1; // 連續幀門檻（幾幀都正確才算「對」）

  // ✅ 前鏡頭擷取是否要做水平翻轉（用於送往模型推論）。
  // 預設 false：避免與某些裝置已非鏡像的擷取影像「重覆翻轉」。
  // 若你的模型是以「自拍鏡像」資料訓練，可改成 true。
  static const bool _flipFrontBytesForInference = false;

  final List<String> _predHist = [];
  String _detected = ""; // 平滑後的辨識和弦
  int _okStreak = 0; // 目前連續正確幀數

  // 統計
  int _framesSent = 0; // 總送出幀數
  int _framesConsidered = 0; // 有目標和弦的幀數
  int _framesCorrect = 0; // 正確幀數
  int _framesWrong = 0; // 錯誤幀數
  int _longestStreak = 0; // 最長連續正確
  double _latencySumMs = 0; // 端到端延遲和
  int _latencyCount = 0; // 延遲樣本數
  final Map<String, int> _attemptsByChord = {}; // 每個目標和弦的嘗試次數
  final Map<String, int> _correctByChord = {}; // 每個目標和弦的正確次數

  // 🔔 全螢幕相機需要「即時顯示目前應彈和弦」，用 ValueNotifier 讓畫面即時更新
  final ValueNotifier<String> _expectedChordVN = ValueNotifier<String>('');

  // ---- 歌曲資料（可先不加 offsetMs；程式會等分）----
  final List<Map<String, dynamic>> songData = const [
    {
      "time": Duration(seconds: 29),
      "lyrics": "故事的小黃花",
      "chords": [
        {"pos": 0, "chord": "Em7", "offsetMs": 0},
        {"pos": 3, "chord": "Cadd9", "offsetMs": 1116},
      ],
    },
    {
      "time": Duration(seconds: 32),
      "lyrics": "從出生那年就飄著",
      "chords": [
        {"pos": 0, "chord": "G", "offsetMs": 0},
        {"pos": 6, "chord": "D/F#", "offsetMs": 3000},
      ],
    },
    {
      "time": Duration(seconds: 36),
      "lyrics": "童年的盪鞦韆",
      "chords": [
        {"pos": 0, "chord": "Em7", "offsetMs": 0},
        {"pos": 4, "chord": "Cadd9", "offsetMs": 1900},
      ],
    },
    {
      "time": Duration(seconds: 39),
      "lyrics": "隨記憶一直晃到現在",
      "chords": [
        {"pos": 0, "chord": "G", "offsetMs": 0},
        {"pos": 7, "chord": "D/F#", "offsetMs": 2200},
      ],
    },
    {
      "time": Duration(seconds: 42),
      "lyrics": "ㄖㄨㄟㄙㄡㄙㄡㄒ一ㄉㄛㄒ一ㄌㄚ",
      "chords": [
        {"pos": 0, "chord": "Em7", "offsetMs": 0},
        {"pos": 9, "chord": "Cadd9", "offsetMs": 2200},
      ],
    },
    {
      "time": Duration(seconds: 45),
      "lyrics": "ㄙㄡㄌㄚㄒ一ㄒ一ㄒ一ㄒ一ㄌㄚㄒ一ㄌㄚㄙㄡ",
      "chords": [
        {"pos": 4, "chord": "G", "offsetMs": 1200},
        {"pos": 18, "chord": "D/F#", "offsetMs": 4000},
      ],
    },
    {
      "time": Duration(seconds: 49),
      "lyrics": "吹著前奏望著天空",
      "chords": [
        {"pos": 0, "chord": "Em7", "offsetMs": 0},
        {"pos": 4, "chord": "Cadd9", "offsetMs": 2200},
      ],
    },
    {
      "time": Duration(seconds: 53),
      "lyrics": "我想起花瓣試著掉落",
      "chords": [
        {"pos": 1, "chord": "G", "offsetMs": 150},
        {"pos": 8, "chord": "D/F#", "offsetMs": 3000},
      ],
    },
    {
      "time": Duration(seconds: 56),
      "lyrics": "為妳翹課的那一天",
      "chords": [
        {"pos": 1, "chord": "Em7", "offsetMs": 1000},
      ],
    },
    {
      "time": Duration(seconds: 59),
      "lyrics": "花落的那一天 ",
      "chords": [
        {"pos": 0, "chord": "Cadd9", "offsetMs": 0},
        {"pos": 6, "chord": "G", "offsetMs": 1100},
      ],
    },
    {
      "time": Duration(seconds: 60),
      "lyrics": "教室的那一間",
      "chords": [],
    },
    {
      "time": Duration(seconds: 62),
      "lyrics": "我怎麼看不見",
      "chords": [
        {"pos": 3, "chord": "D/F#", "offsetMs": 1000},
      ],
    },
    {
      "time": Duration(seconds: 64),
      "lyrics": "消失的下雨天",
      "chords": [
        {"pos": 0, "chord": "Em7", "offsetMs": 0},
      ],
    },
    {
      "time": Duration(seconds: 66),
      "lyrics": "我好想再淋一遍- - ",
      "chords": [
        {"pos": 0, "chord": "Cadd9", "offsetMs": 0},
        {"pos": 6, "chord": "G", "offsetMs": 1100},
        {"pos": 10, "chord": "D/F#", "offsetMs": 4000},
      ],
    },
    {
      "time": Duration(seconds: 70),
      "lyrics": "沒想到失去的勇氣我還留著",
      "chords": [
        {"pos": 4, "chord": "Em7", "offsetMs": 1115},
        {"pos": 8, "chord": "Cadd9", "offsetMs": 2226},
        {"pos": 11, "chord": "G", "offsetMs": 4030},
      ],
    },
    {
      "time": Duration(seconds: 76),
      "lyrics": "好想再問一遍",
      "chords": [
        {"pos": 4, "chord": "D/F#", "offsetMs": 1300},
      ],
    },
    {
      "time": Duration(seconds: 78),
      "lyrics": "你會等待還是離開- - ",
      "chords": [
        {"pos": 0, "chord": "Em7", "offsetMs": 0},
        {"pos": 4, "chord": "Cadd9", "offsetMs": 1124},
        {"pos": 8, "chord": "Dsus4", "offsetMs": 3100},
        {"pos": 10, "chord": "D", "offsetMs": 4417},
      ],
    },
    {
      "time": Duration(seconds: 85),
      "lyrics": "颳風這天",
      "chords": [
        {"pos": 0, "chord": "G", "offsetMs": 0},
      ],
    },
    {
      "time": Duration(seconds: 87),
      "lyrics": "我試過握著你手",
      "chords": [
        {"pos": 3, "chord": "Em7", "offsetMs": 1223},
      ],
    },
    {
      "time": Duration(seconds: 90),
      "lyrics": "但偏偏 雨漸漸 ",
      "chords": [
        {"pos": 3, "chord": "C", "offsetMs": 1280},
        {"pos": 7, "chord": "D", "offsetMs": 3240},
      ],
    },
    {
      "time": Duration(seconds: 94),
      "lyrics": "大到我看妳不見",
      "chords": [
        {"pos": 3, "chord": "G", "offsetMs": 1170},
      ],
    },
    {
      "time": Duration(seconds: 98),
      "lyrics": "還要多久",
      "chords": [
        {"pos": 0, "chord": "B", "offsetMs": 0},
      ],
    },
    {
      "time": Duration(seconds: 101),
      "lyrics": "我才能在你身邊",
      "chords": [
        {"pos": 3, "chord": "Em7", "offsetMs": 1223},
      ],
    },
    {
      "time": Duration(seconds: 105),
      "lyrics": "等到放晴的那天",
      "chords": [
        {"pos": 1, "chord": "C", "offsetMs": 1000},
      ],
    },
    {
      "time": Duration(seconds: 108),
      "lyrics": "也許我會比較好一點",
      "chords": [
        {"pos": 2, "chord": "Dsus4", "offsetMs": 1120},
        {"pos": 6, "chord": "D", "offsetMs": 3000},
      ],
    },
    {
      "time": Duration(seconds: 112),
      "lyrics": "從前從前",
      "chords": [
        {"pos": 0, "chord": "G", "offsetMs": 0},
      ],
    },
    {
      "time": Duration(seconds: 115),
      "lyrics": "有個人愛妳很久",
      "chords": [
        {"pos": 3, "chord": "Em7", "offsetMs": 1223},
      ],
    },
    {
      "time": Duration(seconds: 118),
      "lyrics": "但偏偏 風漸漸 ",
      "chords": [
        {"pos": 3, "chord": "C", "offsetMs": 1280},
        {"pos": 7, "chord": "D", "offsetMs": 3240},
      ],
    },
    {
      "time": Duration(seconds: 122),
      "lyrics": "把距離吹得好遠",
      "chords": [
        {"pos": 3, "chord": "G", "offsetMs": 1170},
      ],
    },
    {
      "time": Duration(seconds: 126),
      "lyrics": "好不容易",
      "chords": [
        {"pos": 0, "chord": "B", "offsetMs": 0},
      ],
    },
    {
      "time": Duration(seconds: 129),
      "lyrics": "又能再多愛一天",
      "chords": [
        {"pos": 3, "chord": "Em7", "offsetMs": 1223},
      ],
    },
    {
      "time": Duration(seconds: 133),
      "lyrics": "但故事的最後",
      "chords": [
        {"pos": 1, "chord": "C", "offsetMs": 1000},
      ],
    },
    {
      "time": Duration(seconds: 136),
      "lyrics": "你好像還是說了 掰掰",
      "chords": [
        {"pos": 3, "chord": "Dsus4", "offsetMs": 1120},
        {"pos": 7, "chord": "D", "offsetMs": 3000},
        {"pos": 9, "chord": "G", "offsetMs": 3350},
      ],
    },
  ];

  // ---- 狀態（保留）----
  int currentLineIndex = 0;
  String currentChord = "";
  final ScrollController _scroll = ScrollController();
  static const double _lineHeight = 96.0;
  double x = 16, y = 420;

  // ---- 時間軸 & 播放位置 ----
  Duration _lastPos = Duration.zero;
  List<_ChordEvt> _timeline = [];
  int _evtIdx = 0;
  _ChordEvt? _activeEvt;
  static const int _graceMs = 250;

  // 斜線與常見別名標準化
  static const Map<String, String> _aliases = {
    'D/F#': 'D_F#',
    'D7/F#': 'D7_F#',
  };

  @override
  void initState() {
    // 保持螢幕常亮（進入此頁面即啟用）
    WakelockPlus.enable();
    super.initState();

    // 建立「無縫」和弦時間軸（上一顆撐到下一顆；支援 offsetMs；沒有就等分）
    _timeline = _buildTimeline(songData);
    _evtIdx = 0;
    _activeEvt = null;

    _initCamera(prefer: CameraLensDirection.front); // 預設前鏡頭
    _resetMetrics();
    _startAudioAndListen('audio/songs/晴天.MP3');
  }

  // ---------- 相機 ----------
  Future<void> _initCamera({CameraLensDirection prefer = CameraLensDirection.front}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final cam = cameras.firstWhere(
        (c) => c.lensDirection == prefer,
        orElse: () => cameras.first,
      );

      await _controller?.dispose();

      _controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _camReady = true);

      // 相機就緒後，啟動固定頻率推論
      _inferTimer?.cancel();
      _inferTimer = Timer.periodic(
        const Duration(milliseconds: 600),
        (_) => _captureAndPredict(),
      );
    } catch (e) {
      debugPrint('相機初始化失敗: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (!mounted) return;
    final current = _controller?.description.lensDirection ?? CameraLensDirection.front;
    final next = (current == CameraLensDirection.back)
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    setState(() => _camReady = false);
    await _initCamera(prefer: next);
  }

  // ---------- 音訊 ----------
  Future<void> _startAudioAndListen(String rel) async {
    try {
      _posSub?.cancel();
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);

      if (kIsWeb) {
        await _player.setSourceUrl('assets/$rel');
      } else {
        await _player.setSourceAsset(rel);
      }

      // 開始播放並監聽位置（改用 _onPos）
      await _player.resume();
      _posSub = _player.onPositionChanged.listen(_onPos);

      // 歌曲播放完畢→進入成績頁
      _player.onPlayerComplete.listen((_) {
        _finishAndShowScore();
      });
    } catch (e) {
      debugPrint('音訊錯誤: $e');
    }
  }

  void _resetMetrics() {
    _predHist.clear();
    _detected = "";
    _okStreak = 0;

    _framesSent = 0;
    _framesConsidered = 0;
    _framesCorrect = 0;
    _framesWrong = 0;
    _longestStreak = 0;
    _latencySumMs = 0;
    _latencyCount = 0;
    _attemptsByChord.clear();
    _correctByChord.clear();
  }

  // ---------- 位置更新（以時間軸同步） ----------
  void _onPos(Duration pos) {
    _lastPos = pos;
    _syncExpectedByTimeline(pos);
  }

  void _syncExpectedByTimeline(Duration pos) {
    if (_timeline.isEmpty) return;

    // 用 _evtIdx 做雙向滑動，避免每次從頭找
    while (_evtIdx + 1 < _timeline.length && pos >= _timeline[_evtIdx].end) {
      _evtIdx++;
    }
    while (_evtIdx > 0 && pos < _timeline[_evtIdx].start) {
      _evtIdx--;
    }

    final evt = _timeline[_evtIdx];
    final bool inEvt = (pos >= evt.start && pos < evt.end);

    if (inEvt) {
      _activeEvt = evt;
      if (evt.chord != currentChord) {
        setState(() => currentChord = evt.chord); // 顯示保留原字串（不強制轉 alias）
        _expectedChordVN.value = evt.chord; // 🔔 通知全螢幕疊層即時更新
      }
    } else {
      // 不在任何事件內：保留畫面上的和弦，不清空（直到下一顆出現才換）
      _activeEvt = null; // 評分仍只在事件內進行
    }

    // 歌詞行同步（仍用每行的 time）
    int newLine = 0;
    for (int i = 0; i < songData.length; i++) {
      final t = songData[i]['time'] as Duration;
      if (pos >= t) newLine = i;
    }
    if (newLine != currentLineIndex) {
      setState(() => currentLineIndex = newLine);
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    final target = currentLineIndex * _lineHeight;
    _scroll
        .animateTo(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        )
        .catchError((_) {});
  }

  // ---------- 推論循環 ----------
  Future<void> _captureAndPredict() async {
    if (_inferBusy || !_camReady || _controller == null || !_controller!.value.isInitialized) return;
    _inferBusy = true;

    final t0 = DateTime.now().millisecondsSinceEpoch;
    try {
      _framesSent += 1;

      // 取一張 JPEG 並用 bytes 上傳
      final shot = await _controller!.takePicture();
      Uint8List bytes = await shot.readAsBytes();

      // 校正 EXIF；為避免鏡像錯亂，預設不對前鏡頭做翻轉（只翻預覽）。
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        img.Image fixed = img.bakeOrientation(decoded);
        final bool isFront = _controller!.description.lensDirection == CameraLensDirection.front;
        if (isFront && _flipFrontBytesForInference) {
          fixed = img.flipHorizontal(fixed);
        }
        bytes = Uint8List.fromList(img.encodeJpg(fixed, quality: 90));
      }

      final res = await Api.predictBytes(bytes);
      final label = (res['chord'] ?? '').toString();
      final clientMs = DateTime.now().millisecondsSinceEpoch - t0; // 端到端

      _latencySumMs += clientMs;
      _latencyCount += 1;

      // 多數決平滑
      _predHist.add(label);
      if (_predHist.length > _win) _predHist.removeAt(0);
      final majority = _majority(_predHist);
      _detected = majority;

      // ---- 計分（只在目前有和弦區間，且超過緩衝期才計）----
      final expected = (_activeEvt == null) ? "" : _norm(_activeEvt!.chord);
      if (_activeEvt != null && expected.isNotEmpty) {
        final msInto = (_lastPos - _activeEvt!.start).inMilliseconds;
        final inGrace = msInto < _graceMs;

        if (!inGrace) {
          _framesConsidered += 1;
          _attemptsByChord[expected] = (_attemptsByChord[expected] ?? 0) + 1;

          final got = _norm(_detected);
          if (got.isNotEmpty && got == expected) {
            _framesCorrect += 1;
            _correctByChord[expected] = (_correctByChord[expected] ?? 0) + 1;
            _okStreak += 1;
            if (_okStreak > _longestStreak) _longestStreak = _okStreak;
          } else {
            _framesWrong += 1;
            _okStreak = 0;
          }
        }
      } else {
        _okStreak = 0;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('predict error: $e');
    } finally {
      _inferBusy = false;
    }
  }

  String _majority(List<String> xs) {
    if (xs.isEmpty) return "";
    final m = <String, int>{};
    for (final x in xs) {
      m[x] = (m[x] ?? 0) + 1;
    }
    return m.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _norm(String s) {
    s = s.trim().replaceAll('/', '_');
    return _aliases[s] ?? s;
  }

  // ---------- 完成並顯示成績（改：僅顯示成績；點和弦導向 chordchart.dart） ----------
  Future<void> _finishAndShowScore() async {
    try {
      _inferTimer?.cancel();
      _inferTimer = null;
      await _player.stop();
    } catch (_) {}

    final avgLatency = _latencyCount == 0 ? 0.0 : _latencySumMs / _latencyCount.toDouble();
    final accuracy = _framesConsidered == 0 ? 0.0 : _framesCorrect / _framesConsidered;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ChordScorePage(
          totalFrames: _framesSent,
          considered: _framesConsidered,
          correct: _framesCorrect,
          wrong: _framesWrong,
          longestStreak: _longestStreak,
          avgLatencyMs: avgLatency,
          attemptsByChord: Map<String, int>.from(_attemptsByChord),
          correctByChord: Map<String, int>.from(_correctByChord),
          finalAccuracy: accuracy,
        ),
      ),
    );

    // 回到頁面後：單純重置並繼續
    _resetMetrics();
    try {
      await _player.resume();
      _inferTimer ??=
          Timer.periodic(const Duration(milliseconds: 600), (_) => _captureAndPredict());
    } catch (_) {}
  }

  @override
  void dispose() {
    // 離開頁面時恢復系統預設（允許休眠）
    WakelockPlus.disable();
    _posSub?.cancel();
    _player.stop();
    _player.dispose();
    _inferTimer?.cancel();
    _controller?.dispose();
    _scroll.dispose();
    _expectedChordVN.dispose();
    super.dispose();
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final camReady = _camReady && _controller != null && _controller!.value.isInitialized;
    final bool okNow = _okStreak >= _need;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('周杰倫 - 晴天'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: '切換前/後鏡頭',
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
          ),
          TextButton(
            onPressed: _finishAndShowScore,
            child: const Text('結束並看成績', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentChord.isEmpty ? '和弦（應彈）：' : '和弦（應彈）：$currentChord',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        _detected.isEmpty ? '辨識：—' : '辨識：$_detected',
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        okNow ? '✅ 正確' : '…偵測中',
                        style: TextStyle(
                          color: okNow ? Colors.lightGreenAccent : Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    itemCount: songData.length,
                    itemBuilder: (_, i) => _buildChordLyricLine(
                      songData[i],
                      i == currentLineIndex,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (camReady)
            Positioned(
              left: x,
              top: y,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    x += d.delta.dx;
                    y += d.delta.dy;
                    final size = MediaQuery.of(context).size;
                    x = x.clamp(0.0, size.width - 160);
                    y = y.clamp(0.0, size.height - 120);
                  });
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CameraQingtianFullScreen(
                        controller: _controller!,
                        expectedVN: _expectedChordVN, // ✅ 全螢幕疊層即時顯示應彈和弦
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 160,
                        height: 120,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: (_controller?.description.lensDirection ==
                                  CameraLensDirection.front)
                              ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0)) // 前鏡頭預覽水平反轉
                              : Matrix4.identity(),
                          child: CameraPreview(_controller!),
                        ),
                      ),
                      // 🔲 在小窗左上角也顯示一個小框框提示應彈和弦（可移除）
                      Positioned(
                        top: 6,
                        left: 6,
                        child: ValueListenableBuilder<String>(
                          valueListenable: _expectedChordVN,
                          builder: (_, chord, __) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white70),
                            ),
                            child: Text(
                              chord.isEmpty ? '—' : chord,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChordLyricLine(Map<String, dynamic> line, bool active) {
    final lyrics = line['lyrics'] as String;
    final chords = line['chords'] as List<dynamic>;
    final chars = lyrics.split('');
    final Map<int, String> chordMap = {};
    for (final c in chords) {
      final p = c['pos'] as int;
      final ch = c['chord'] as String;
      if (p >= 0 && p < chars.length) chordMap[p] = ch;
    }
    return Container(
      height: _lineHeight,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(chars.length, (i) {
                final text = chordMap[i] ?? '';
                return Expanded(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: active ? Colors.greenAccent : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(chars.length, (i) {
                return Expanded(
                  child: Text(
                    chars[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: active ? 22 : 18,
                      color: active ? Colors.white : Colors.white70,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 把 songData 轉成「無縫」時間軸（上一顆撐到下一顆；支援 offsetMs；沒有就等分）----
  List<_ChordEvt> _buildTimeline(List<Map<String, dynamic>> data) {
    final points = <MapEntry<Duration, String>>[];
    Duration lastLineEnd = Duration.zero;

    for (int i = 0; i < data.length; i++) {
      final Duration t0 = data[i]['time'] as Duration;
      final Duration t1 = (i + 1 < data.length)
          ? data[i + 1]['time'] as Duration
          : t0 + const Duration(seconds: 4); // 歌尾預設留 4 秒
      lastLineEnd = t1;

      final chords = (data[i]['chords'] as List).cast<Map<String, dynamic>>();
      if (chords.isEmpty) continue;

      final hasOffsets = chords.every((c) => c.containsKey('offsetMs'));
      if (hasOffsets) {
        for (final c in chords) {
          final start = t0 + Duration(milliseconds: (c['offsetMs'] as int));
          final chord = (c['chord'] as String); // 顯示保留原字串
          points.add(MapEntry(start, chord));
        }
      } else {
        // 沒 offsetMs → 這一行平均切，但後面仍會「撐到下一顆」避免空窗
        final segMs = (t1 - t0).inMilliseconds / chords.length;
        for (int j = 0; j < chords.length; j++) {
          final start = t0 + Duration(milliseconds: (j * segMs).round());
          final chord = (chords[j]['chord'] as String);
          points.add(MapEntry(start, chord));
        }
      }
    }

    if (points.isEmpty) return [];

    points.sort((a, b) => a.key.compareTo(b.key));

    // 同一時間點若有重複，只保留最後一筆
    final dedup = <MapEntry<Duration, String>>[];
    for (final p in points) {
      if (dedup.isNotEmpty && dedup.last.key == p.key) {
        dedup.removeLast();
      }
      dedup.add(p);
    }

    final out = <_ChordEvt>[];
    for (int i = 0; i < dedup.length; i++) {
      final start = dedup[i].key;
      final end = (i + 1 < dedup.length) ? dedup[i + 1].key : lastLineEnd;
      if (end <= start) continue; // 避免零長度
      out.add(_ChordEvt(start, end, dedup[i].value));
    }
    return out;
  }
}

class CameraQingtianFullScreen extends StatelessWidget {
  final CameraController controller;
  final ValueListenable<String> expectedVN; // ✅ 全螢幕同步顯示應彈和弦
  const CameraQingtianFullScreen({super.key, required this.controller, required this.expectedVN});

  @override
  Widget build(BuildContext context) {
    final isFront = controller.description.lensDirection == CameraLensDirection.front;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: isFront ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0)) : Matrix4.identity(),
              child: CameraPreview(controller),
            ),
          ),

          // 🔲 置中的「應彈和弦」框框：點擊即可返回
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: ValueListenableBuilder<String>(
                  valueListenable: expectedVN,
                  builder: (_, chord, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          chord.isEmpty ? '—' : '應彈：$chord',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('（點我返回）', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 左上角關閉按鈕（保留原功能）
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 成績頁 ============
class _ChordScorePage extends StatelessWidget {
  final int totalFrames;
  final int considered;
  final int correct;
  final int wrong;
  final int longestStreak;
  final double avgLatencyMs;
  final Map<String, int> attemptsByChord;
  final Map<String, int> correctByChord;
  final double finalAccuracy;

  const _ChordScorePage({
    required this.totalFrames,
    required this.considered,
    required this.correct,
    required this.wrong,
    required this.longestStreak,
    required this.avgLatencyMs,
    required this.attemptsByChord,
    required this.correctByChord,
    required this.finalAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    final items = attemptsByChord.keys.toList()..sort();

    // === 找出最弱和弦（跳過 att=0）；同準確率→取嘗試次數較多者 ===
    String? worstChord;
    double worstAcc = 1.0;
    int worstAtt = -1;
    for (final ch in items) {
      final att = attemptsByChord[ch] ?? 0;
      final cor = correctByChord[ch] ?? 0;
      if (att <= 0) continue;
      final acc = cor / att;
      if (acc < worstAcc || (acc == worstAcc && att > worstAtt)) {
        worstAcc = acc;
        worstAtt = att;
        worstChord = ch;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('成績統計'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _stat('整體準確率', '${(finalAccuracy * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            _stat('最長連續正確', '$longestStreak 幀'),
            _stat('送出幀數', '$totalFrames'),
            _stat('有效幀數（有目標和弦）', '$considered'),
            _stat('正確 / 錯誤', '$correct / $wrong'),
            _stat('平均端到端延遲', '${avgLatencyMs.toStringAsFixed(0)} ms'),
            const Divider(color: Colors.white24, height: 24),
            const Text(
              '各和弦表現（點擊可前往和弦總表）',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // === 可點擊的各和弦列 → 前往 chordchart.dart ===
            for (final chord in items)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChordChart(selected: chord),
                    ),
                  );
                },
                child: _chordRow(
                  chord,
                  attemptsByChord[chord] ?? 0,
                  correctByChord[chord] ?? 0,
                ),
              ),

            const SizedBox(height: 24),

            // === 一鍵查看最弱和弦（導向和弦總表） ===
            if (worstChord != null)
              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChordChart(selected: worstChord),
                    ),
                  );
                },
                child: Text('看最弱和弦：$worstChord（${(worstAcc * 100).toStringAsFixed(0)}%）'),
              )
            else
              const Text('尚無可分析的和弦資料', style: TextStyle(color: Colors.white38)),

            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chordRow(String chord, int att, int cor) {
    final acc = att == 0 ? 0.0 : cor / att;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              chord,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: acc,
              minHeight: 10,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(acc * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Text(
            '$cor/$att',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
