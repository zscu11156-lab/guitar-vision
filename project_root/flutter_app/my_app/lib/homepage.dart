import 'package:flutter/material.dart';
import 'settings.dart';
import 'learn.dart';
import 'challenge.dart';
import 'member.dart';
import 'tuner.dart';
import 'chordchart.dart'; // 你的和弦字典頁

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ① 主要內容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 64),

                  // ── Guitar Vision 標題 ──
                  const Center(
                    child: Text(
                      'Guitar\nVision',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LaBelleAurore',
                        fontSize: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),

                  // ── Learn & Challenge ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FeatureButton(
                        image: 'assets/images/learn.png',
                        label: 'learn',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LearnPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 100),
                      _FeatureButton(
                        image: 'assets/images/challenge.png',
                        label: 'challenge',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChallengePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 100), // 保留空間給下方導覽列
                ],
              ),
            ),

            // ② 齒輪設定按鈕
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

      // ③ BottomBar 導覽列（黑底）
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
            // Home（目前頁，不跳轉）
            _NavItem(img: 'assets/images/home.png', size: navIcon),

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

// ── Learn / Challenge 按鈕元件 ──
class _FeatureButton extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback? onTap;

  const _FeatureButton({
    required this.image,
    required this.label,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Image.asset(image, width: 140),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'LaBelleAurore',
                fontSize: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
}

// ── BottomBar 元件 ──
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
