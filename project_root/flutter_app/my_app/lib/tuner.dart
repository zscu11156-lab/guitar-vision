// lib/turner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'chordchart.dart';
import 'member.dart';

// 偵測引擎（沿用你現有的）
import 'tuner_engine.dart';

// 允許執行時請求麥克風權限
import 'package:permission_handler/permission_handler.dart';

class GvTunerPage extends StatefulWidget {
  const GvTunerPage({super.key});

  @override
  State<GvTunerPage> createState() => _GvTunerPageState();
}

class _GvTunerPageState extends State<GvTunerPage> {
  final TunerEngine _engine = TunerEngine();
  TunerState _s = TunerState.empty;
  StreamSubscription<TunerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _engine.stream.listen((st) {
      if (!mounted) return;
      setState(() => _s = st);
    });
    _initPermissionsAndStart(); // 先要權限，再啟動偵測
  }

  Future<void> _initPermissionsAndStart() async {
    final mic = await Permission.microphone.request();
    if (mic.isGranted) {
      if (!mounted) return;
      _engine.start(); // 開始收音 + 偵測
    } else if (mic.isPermanentlyDenied) {
      await openAppSettings(); // 使用者不再詢問 → 導到設定
    } else {
      debugPrint('麥克風權限未授予');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    final String noteLine = _s.note.isEmpty ? '—' : '${_s.note}（${_s.hint}）';
    final String freqLine = '${_s.freq.toStringAsFixed(2)} Hz';
    final String dir = _s.diff.abs() < 1 ? '準確' : (_s.diff > 0 ? '偏高' : '偏低');
    final String diffLine =
        '與標準值偏差：${_s.diff >= 0 ? '+' : ''}${_s.diff.toStringAsFixed(2)} Hz（$dir）';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 32),
                  const Center(
                    child: Text(
                      'Tuner',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'LaBelleAurore',
                        fontSize: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 中央資訊
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        noteLine,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        freqLine,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        diffLine,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _s.advice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // 偏差指示條（中心=0Hz，左右=±20Hz）
                      _DiffBar(diffHz: _s.diff),
                      const SizedBox(height: 16),
                      const Text(
                        '保持單弦發聲，環境盡量安靜',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
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

      // 底部導覽列
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
            // Home
            _NavItem(
              img: 'assets/images/home.png',
              size: navIcon,
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              },
            ),
            // Tuner（目前頁）
            const _NavItem(
              img: 'assets/images/tuner.png',
              size: navIcon,
              onTap: null,
            ),
            // Chord Chart
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

// 偏差指示條：中心=0Hz，兩端=±20Hz
class _DiffBar extends StatelessWidget {
  final double diffHz;
  const _DiffBar({required this.diffHz});

  @override
  Widget build(BuildContext context) {
    const double maxAbs = 20; // 兩端極限：±20 Hz
    final double clamped = diffHz.clamp(-maxAbs, maxAbs);
    final double x = (clamped / maxAbs); // -1..1（左=偏低，右=偏高）
    final Color dotColor =
        diffHz.abs() < 1 ? Colors.greenAccent : Colors.orangeAccent;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final center = w / 2;
        final pos = center + x * (w / 2 - 8); // 8 = 圓點半徑

        return SizedBox(
          width: double.infinity,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 軌道
              Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // 中央 0Hz 刻度
              Container(width: 2, height: 16, color: Colors.white38),
              // 左右標記
              Positioned(
                left: 0,
                top: 20,
                child: const Text(
                  '-20 Hz',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              Positioned(
                right: 0,
                top: 20,
                child: const Text(
                  '+20 Hz',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              // 位置點
              Positioned(
                left: pos - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
