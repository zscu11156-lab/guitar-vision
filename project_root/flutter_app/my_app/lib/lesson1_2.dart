import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'lesson1.dart';
import 'lesson1_3.dart';
import 'flip_page_route.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class Lesson1Page2 extends StatelessWidget {
  const Lesson1Page2({super.key});

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 內容 (只有圖片)
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    'assets/images/L1-2.png', // 第二頁圖片
                    fit: BoxFit.contain,
                  ),
                ),
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

            // 左下返回箭頭（回 Lesson1Page1）→ 換成圖片 arrow l.png
            Positioned(
              left: 24,
              bottom: 110,
              child: IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(), // 讓按鈕緊貼圖片大小
                onPressed: () {
                  // 保留翻頁動畫
                  Navigator.pushReplacement(
                    context,
                    FlipPageRoute(child: const Lesson1Page()),
                  );
                  // 若只想返回上一頁：Navigator.pop(context);
                },
                icon: Image.asset(
                  'assets/images/arrow l.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
                // 需要著色可以改為：
                // icon: const ImageIcon(AssetImage('assets/images/arrow l.png'), color: Colors.white70),
              ),
            ),

            // 右下前往下一頁 → 換成圖片 arrow r.png
            Positioned(
              right: 24,
              bottom: 110,
              child: IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.of(context).push(
                    FlipPageRoute(child: const Lesson1Page3()),
                  );
                },
                icon: Image.asset(
                  'assets/images/arrow r.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
                // 若要著色：
                // icon: const ImageIcon(AssetImage('assets/images/arrow r.png'), color: Colors.white70),
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

// 底部導覽列項目
class _NavItem extends StatelessWidget {
  final String img;
  final double size;
  final VoidCallback? onTap;
  const _NavItem({
    required this.img,
    required this.size,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(child: Image.asset(img, width: size)),
        ),
      );
}
