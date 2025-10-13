import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'lesson2_3.dart';
import 'flip_page_route.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';
import 'lesson2test.dart';

class Lesson2Page4 extends StatelessWidget {
  const Lesson2Page4({super.key});

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
                  // ← 左：圖片，往下 48
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          'assets/images/Em-.png',
                          fit: BoxFit.contain,
                        ),
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
                            '和弦按法',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          _BulletText('最後是Em和弦'),
                          SizedBox(height: 16),
                          Text(
                            '食中指放在2品5弦上，無名指放在2品4弦上\n*其餘基本和弦在和弦表中，請自行學習',
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
            // 底部左箭頭（上一頁）→ 改成圖片 arrow l.png
            Positioned(
              left: 24,
              bottom: 110,
              child: IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    FlipPageRoute(child: const Lesson2Page3()),
                  );
                },
                icon: Image.asset(
                  'assets/images/arrow l.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
                // 若要著色可改為：
                // icon: const ImageIcon(AssetImage('assets/images/arrow l.png'), color: Colors.white70),
              ),
            ),
            // 底部右側 "test" 按鈕（跳到 Lesson2TestPage）
            Positioned(
              right: 24,
              bottom: 110, // 與左箭頭同高，避免被底部導覽列擋住
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xAA000000),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    FlipPageRoute(child: const Lesson2TestPage()),
                  );
                },
                child: const Text(
                  'test',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),

      // 底部導覽列（新版）
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
