import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'lesson3_3.dart'; // ← 回上一頁
import 'lesson3_5.dart'; // ← 下一頁
import 'flip_page_route.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class Lesson3Page4 extends StatelessWidget {
  const Lesson3Page4({super.key});

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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ← 左：兩張圖片（Em.png 與 G.png），往下 150
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 150),
                      child: Row(
                        children: [
                          // Em.png
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Image.asset(
                                'assets/chords/Em.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 0), // 需要間距可改 12
                          // G.png
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Image.asset(
                                'assets/chords/G.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // → 右：文字，往下 96
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SizedBox(height: 8),
                          Text(
                            '和弦轉換',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                          _BulletText('Em → G'),
                          SizedBox(height: 16),
                          Text(
                            'Em(022000) → G(320033)：常見兩種做法。'
                            '①「滑動中指」：中指由 A2 滑到 E3，食指補到 A2，無名指落 B3，小指落 e3；'
                            '②「先錨後補」：先放無名與小指在 B3/e3 當錨，再放中指 E3、最後補食指 A2。'
                            '反向 G→Em：抬起小指、放鬆多餘手指位移，保留開弦清楚響應。'
                            '重點：最少位移、同時落弦；G 可全弦刷，Em 注意避免雜音。',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
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

            // 左下：上一頁（arrow l.png）
            Positioned(
              left: 24,
              bottom: 110,
              child: IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(const Size(36, 36)),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    FlipPageRoute(child: const Lesson3Page3()),
                  );
                },
                icon: Image.asset(
                  'assets/images/arrow l.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 右下：下一頁（arrow r.png）→ lesson3_5.dart
            Positioned(
              right: 24,
              bottom: 110,
              child: IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    FlipPageRoute(child: const Lesson3Page5()),
                  );
                },
                icon: Image.asset(
                  'assets/images/arrow r.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
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
            // Tuner
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

/// 子彈點文字
class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•  ',
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// 底部導覽列項目
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
