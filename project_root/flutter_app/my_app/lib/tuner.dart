// lib/tuner.dart  或  lib/gv_tuner_page.dart（依你的檔名）
// 完整可覆蓋版：含螢幕常亮、生命週期管理、靈敏度調整

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'homepage.dart';
import 'settings.dart';
import 'chordchart.dart';
import 'member.dart';

// 偵測引擎
import 'tuner_engine.dart';

class GvTunerPage extends StatefulWidget {
  const GvTunerPage({super.key});

  @override
  State<GvTunerPage> createState() => _GvTunerPageState();
}

class _GvTunerPageState extends State<GvTunerPage> with WidgetsBindingObserver {
  final TunerEngine _engine = TunerEngine();
  TunerState _s = TunerState.empty;
  StreamSubscription<TunerState>? _sub;

  double _sens = 0.75; // 與引擎同步的靈敏度(0~1; 越大越敏感)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 保持螢幕常亮（調音時不休眠）
    WakelockPlus.enable();

    // 同步 sensitivity
    _sens = _engine.sensitivity;

    // 監聽引擎輸出
    _sub = _engine.stream.listen((st) {
      if (!mounted) return;
      setState(() => _s = st);
    });

    _initPermissionsAndStart(); // 要權限 → 啟動
  }

  Future<void> _initPermissionsAndStart() async {
    final mic = await Permission.microphone.request();
    if (!mounted) return;

    if (mic.isGranted) {
      _engine.start();
    } else if (mic.isPermanentlyDenied) {
      // 導去系統設定
      await openAppSettings();
    } else {
      // 暫時拒絕
      setState(() {
        _s = const TunerState(
          advice: '需要麥克風權限才能偵測，請允許後再試。',
        );
      });
    }
  }

  Future<void> _restart() async {
    await _engine.stop();
    if (!mounted) return;
    _engine.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 背景暫停，回前景自動恢復（避免掛在背景耗電）
    if (state == AppLifecycleState.paused) {
      _engine.stop();
    } else if (state == AppLifecycleState.resumed) {
      _initPermissionsAndStart();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine.dispose();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    final bool hasFreq = _s.freq > 0;
    final bool noInput = !hasFreq &&
        (_s.advice.contains('未收到') || _s.advice.contains('沒有音訊') || _s.advice.contains('權限'));

    final String noteLine = hasFreq && _s.note.isNotEmpty
        ? '${_s.note}（${_s.hint}）'
        : '—';

    final String freqLine = hasFreq
        ? '${_s.freq.toStringAsFixed(2)} Hz'
        : (noInput ? '沒有音訊輸入' : '偵測中…');

    final double cents = _s.diffCents;
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

                      const SizedBox(height: 28),

                      // 靈敏度調整（直接影響開關門檻）
                      Row(
                        children: [
                          const Text('靈敏度', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: _sens,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              label: _sens.toStringAsFixed(2),
                              onChanged: (v) {
                                setState(() {
                                  _sens = v;
                                  _engine.sensitivity = v;
                                });
                              },
                            ),
                          ),
                        ],
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
    if (!cents.isFinite) return '—';
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
