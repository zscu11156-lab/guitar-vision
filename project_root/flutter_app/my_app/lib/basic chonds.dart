// basic_chords.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class BasicChordsPage extends StatelessWidget {
  const BasicChordsPage({super.key});

  // 你要挑戰的和弦清單（可自行調整）
  static const List<String> basicChords = [
    'C',
    'G',
    'D',
    'Em',
    'Am',
    'E',
    'A',
    'Dm',
    'F',
  ];

  // 倒數秒數 & 挑戰作答時間（秒）
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

                  // 標題
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

                  // 說明文字
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          '挑戰開始後',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '會倒數 3 秒',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '之後隨機生成一個和弦',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '要在 10 秒內彈出正確的和弦',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 開始挑戰按鈕
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => BasicChordsChallengePage(
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
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                child: Image.asset('assets/images/Setting.png', width: 50),
              ),
            ),
          ],
        ),
      ),

      // ③ BottomBar 導覽列（黑底）
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
                  Navigator.pop(context); // 從 Home 進來，pop 即可返回
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                  );
                }
              },
            ),
            // microphone -> tuner（跳調音器）
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

            // history -> chordchart（跳和弦字典）
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

/// 挑戰頁（內含 3 秒倒數 -> 顯示隨機和弦 + 10 秒計時）
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
  late int _countdownLeft;
  late int _playLeft;
  String? _targetChord;
  Timer? _countdownTimer;
  Timer? _playTimer;
  bool _inCountdown = true;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _inCountdown = true;
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

  void _startPlay() {
    _inCountdown = false;
    _targetChord = widget.chords[Random().nextInt(widget.chords.length)];
    _playLeft = widget.playDurationSec;
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _playLeft--;
        if (_playLeft <= 0) {
          t.cancel();
          _showTimeUp();
        }
      });
    });
  }

  void _showTimeUp() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '時間到！',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  '剛剛的和弦是：${_targetChord ?? '-'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '關閉',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // 重新挑戰
                        _countdownTimer?.cancel();
                        _playTimer?.cancel();
                        setState(() {
                          _targetChord = null;
                        });
                        _startCountdown();
                      },
                      child: const Text('再玩一次'),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const big = TextStyle(
      color: Colors.white,
      fontFamily: 'ABeeZee',
      fontSize: 80,
    );
    const normal = TextStyle(color: Colors.white, fontSize: 18);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Basic Chords 挑戰'),
        centerTitle: true,
      ),
      body: Center(
        child:
            _inCountdown
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('準備囉', style: normal),
                    const SizedBox(height: 16),
                    Text('$_countdownLeft', style: big),
                  ],
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('請彈出畫面中的和弦', style: normal),
                    const SizedBox(height: 24),
                    Text(_targetChord ?? '-', style: big),
                    const SizedBox(height: 24),
                    Text('剩餘：$_playLeft 秒', style: normal),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        // 手動結束（可改成成功判定後觸發）
                        _playTimer?.cancel();
                        _showTimeUp();
                      },
                      child: const Text('結束挑戰'),
                    ),
                  ],
                ),
      ),
    );
  }
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
