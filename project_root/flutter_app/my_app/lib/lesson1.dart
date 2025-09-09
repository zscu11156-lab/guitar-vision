import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'settings.dart';
import 'flip_page_route.dart';
import 'lesson1_2.dart';
import 'homepage.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class Lesson1Page extends StatefulWidget {
  const Lesson1Page({super.key});

  @override
  State<Lesson1Page> createState() => _Lesson1PageState();
}

class _Lesson1PageState extends State<Lesson1Page> {
  // 6 個說明泡泡的開關
  final Map<String, bool> _open = {
    'tuners': false, // 弦紐
    'nut': false, // 上琴枕
    'frets': false, // 弦桁
    'soundhole': false, // 響孔
    'saddle': false, // 下琴枕
    'bridge': false, // 琴橋
  };

  void _toggle(String id) => setState(() => _open[id] = !(_open[id] ?? false));

  @override
  Widget build(BuildContext context) {
    const bottomBarH = 80.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // 中央圖片 + 熱區
            Center(
              child: LayoutBuilder(
                builder: (_, c) {
                  // 原圖大約 526(w) x 617(h)
                  const imgAspect = 617 / 526; // height / width
                  final maxW =
                      math.min(c.maxWidth, c.maxHeight - bottomBarH) * 0.9;
                  final maxH = (c.maxHeight - bottomBarH) * 0.9;
                  final imgW = math.min(maxW, maxH / imgAspect);
                  final imgH = imgW * imgAspect;

                  return SizedBox(
                    width: imgW,
                    height: imgH,
                    child: Stack(
                      children: [
                        // 圖片
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/guitar.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        // 右側白字的 6 個熱區（座標為百分比：x,y,w,h）
                        _Hotspot(
                          id: 'tuners',
                          rect: const Rect.fromLTWH(0.83, 0.05, 0.12, 0.06),
                          isOpen: _open['tuners']!,
                          onTap: () => _toggle('tuners'),
                          bubbleText: '調整弦的鬆緊，改變音高；順時針轉音升高，逆時針轉音降低。',
                          imgW: imgW,
                          imgH: imgH,
                          preferLeft: true,
                        ),
                        _Hotspot(
                          id: 'nut',
                          rect: const Rect.fromLTWH(0.83, 0.15, 0.12, 0.06),
                          isOpen: _open['nut']!,
                          onTap: () => _toggle('nut'),
                          bubbleText: '固定每條弦的間距。',
                          imgW: imgW,
                          imgH: imgH,
                          preferLeft: true,
                        ),
                        _Hotspot(
                          id: 'frets',
                          rect: const Rect.fromLTWH(0.83, 0.25, 0.12, 0.06),
                          isOpen: _open['frets']!,
                          onTap: () => _toggle('frets'),
                          bubbleText: '琴頸上橫著的金屬條，左手將弦按在上面以決定音高。',
                          imgW: imgW,
                          imgH: imgH,
                          preferLeft: true,
                        ),

                        // ↓↓↓ 下方三個：加入偏移讓泡泡不互蓋 ↓↓↓
                        _Hotspot(
                          id: 'soundhole',
                          rect: const Rect.fromLTWH(0.83, 0.63, 0.12, 0.06),
                          isOpen: _open['soundhole']!,
                          onTap: () => _toggle('soundhole'),
                          bubbleText: '共鳴、放大聲音。',
                          imgW: imgW,
                          imgH: imgH,
                          preferLeft: true,
                          bubbleOffset: const Offset(0, -42),
                        ),
                        _Hotspot(
                          id: 'saddle',
                          rect: const Rect.fromLTWH(0.83, 0.75, 0.12, 0.06),
                          isOpen: _open['saddle']!,
                          onTap: () => _toggle('saddle'),
                          bubbleText: '影響音準並傳導震動。',
                          imgW: imgW,
                          imgH: imgH,
                          preferLeft: false,
                          bubbleOffset: const Offset(0, -10),
                        ),
                        _Hotspot(
                          id: 'bridge',
                          rect: const Rect.fromLTWH(0.84, 0.86, 0.11, 0.06),
                          isOpen: _open['bridge']!,
                          onTap: () => _toggle('bridge'),
                          bubbleText: '固定弦並把震動傳給琴身。',
                          imgW: imgW,
                          imgH: imgH,
                          preferLeft: true,
                          bubbleOffset: const Offset(-6, 40),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 右上設定（改用翻頁特效）
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  FlipPageRoute(child: const SettingsPage()),
                ),
                child: Image.asset('assets/images/Setting.png', width: 44),
              ),
            ),

            // 右下：下一頁（圖片 arrow r）
            Positioned(
              right: 20,
              bottom: 100, // 避開底部導覽列
              child: IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.push(
                    context,
                    FlipPageRoute(child: const Lesson1Page2()),
                  );
                },
                icon: Image.asset(
                  'assets/images/arrow r.png', // ← 你的圖片
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
                // 若想套色可改用：
                // icon: const ImageIcon(AssetImage('assets/images/arrow r.png'), color: Colors.white70),
              ),
            ),
          ],
        ),
      ),

      // 底部導覽列
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

/* ─────────── 透明點擊熱區 + 泡泡 ─────────── */
class _Hotspot extends StatelessWidget {
  final String id;
  final Rect rect; // 相對圖片 [0..1] 的 x,y,w,h
  final bool isOpen;
  final VoidCallback onTap;
  final String bubbleText;
  final double imgW, imgH;
  final bool preferLeft; // 泡泡在左/右
  final Offset bubbleOffset; // 針對單顆泡泡的微調（+右/下、-左/上）

  const _Hotspot({
    required this.id,
    required this.rect,
    required this.isOpen,
    required this.onTap,
    required this.bubbleText,
    required this.imgW,
    required this.imgH,
    this.preferLeft = false,
    this.bubbleOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final left = rect.left * imgW;
    final top = rect.top * imgH;
    final w = rect.width * imgW;
    final h = rect.height * imgH;

    // 泡泡位置
    const bubbleWidthMax = 280.0; // 寬一點，泡泡較扁
    double bubbleLeft =
        preferLeft ? (left - bubbleWidthMax - 12) : (left + w + 12);
    double bubbleTop = top - 12;

    // 套用微調
    bubbleLeft += bubbleOffset.dx;
    bubbleTop += bubbleOffset.dy;

    // 邊界保護
    bubbleLeft = bubbleLeft.clamp(0.0, imgW - bubbleWidthMax);
    bubbleTop = bubbleTop.clamp(0.0, imgH - 200.0);

    return Stack(
      children: [
        // 透明熱區（覆蓋在白色中文文字上）
        Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: const SizedBox.expand(),
          ),
        ),
        // 泡泡
        if (isOpen)
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: bubbleWidthMax),
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    bubbleText,
                    style: const TextStyle(color: Colors.black87, height: 1.4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/* ─────────── 底部導覽列 ─────────── */
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
            // Home
            _nav(
              'assets/images/home.png',
              () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              ),
            ),
            // Tuner
            _nav(
              'assets/images/tuner.png',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GvTunerPage()),
              ),
            ),
            // Chord Chart
            _nav(
              'assets/images/chordchart.png',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChordChart()),
              ),
            ),
            // Member
            _nav(
              'assets/images/member.png',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemberPage()),
              ),
            ),
          ],
        ),
      );

  Widget _nav(String img, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(child: Image.asset(img, width: 50)),
        ),
      );
}
