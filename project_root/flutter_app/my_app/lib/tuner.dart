import 'dart:async';
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'chordchart.dart';
import 'member.dart';

// 偵測引擎
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
      _engine.start();
    } else if (mic.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _restart() async { // ★ 新增：一鍵重啟偵測
    await _engine.stop();
    if (!mounted) return;
    _engine.start();
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

    final bool hasFreq = _s.freq > 0;
    final bool noInput = !hasFreq && (_s.advice.contains('未收到') || _s.advice.contains('沒有音訊'));
    final String noteLine = hasFreq && _s.note.isNotEmpty
        ? '${_s.note}（${_s.hint}）'
        : '—';
    final String freqLine = hasFreq
        ? '${_s.freq.toStringAsFixed(2)} Hz'
        : (noInput ? '沒有音訊輸入' : '偵測中…');
    final double cents = _s.diffCents; // 你的引擎已提供 diffCents
    final String diffLine = hasFreq && _s.note.isNotEmpty
        ? '偏差：${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents（${_dirWord(cents)}）'
        : '—';

    final bool inTune = hasFreq && cents.abs() <= 5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 24),
                  // 標題列 + 狀態點 + 重新啟動
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tuner',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'LaBelleAurore',
                          fontSize: 64,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ★ 狀態點：有頻率=綠；無=灰
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: hasFreq ? Colors.greenAccent : Colors.white24,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ★ 重新啟動按鈕
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: '重新啟動偵測',
                        onPressed: _restart,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 中央資訊
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        noteLine,
                        style: TextStyle(
                          color: inTune ? Colors.greenAccent : Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
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
                        hasFreq
                            ? _s.advice
                            : (noInput
                                ? '未收到麥克風音訊，請確認權限 / 裝置 / 模擬器設定（Extended Controls → Microphone）'
                                : '請以單弦發聲，環境盡量安靜'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // 偏差指示條（中心=0c，左右=±50c）
                      _DiffBarCents(diffCents: cents),
                      const SizedBox(height: 16),
                      const Text(
                        '建議：±5 cents 以內視為準確',
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

      // 底部導覽列
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
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
            const _NavItem(
              img: 'assets/images/tuner.png',
              size: navIcon,
              onTap: null,
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

  String _dirWord(double cents) {
    if (cents.abs() <= 5) return '準確';
    return cents > 0 ? '偏高' : '偏低';
  }
}

// 偏差指示條：中心=0 cents，兩端=±50 cents
class _DiffBarCents extends StatelessWidget {
  final double diffCents;
  const _DiffBarCents({required this.diffCents});

  @override
  Widget build(BuildContext context) {
    const double maxAbs = 50; // ±50 cents
    final double clamped = diffCents.isFinite ? diffCents.clamp(-maxAbs, maxAbs) : 0.0;
    final double x = (clamped / maxAbs); // -1..1（左=偏低，右=偏高）
    final Color dotColor =
        diffCents.isFinite && diffCents.abs() <= 5 ? Colors.greenAccent : Colors.orangeAccent;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final center = w / 2;
        final pos = center + x * (w / 2 - 8); // 8 = 圓點半徑

        return SizedBox(
          width: double.infinity,
          height: 48,
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
              // 中央 0c 刻度
              Container(width: 2, height: 18, color: Colors.white38),
              // 左右標記
              Positioned(
                left: 0,
                top: 22,
                child: const Text(
                  '-50 c',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              Positioned(
                right: 0,
                top: 22,
                child: const Text(
                  '+50 c',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              // 位置點
              Positioned(
                left: pos - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
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
