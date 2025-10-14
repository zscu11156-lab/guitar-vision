// challenge.dart
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'song.dart';
import 'basic chonds.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class ChallengePage extends StatelessWidget {
  const ChallengePage({super.key});

  @override
  Widget build(BuildContext context) {
    const double cardAspectW = 0.32; // 兩個卡片寬度比例
    const double cardAspectH = 0.30; // 卡片高度比例
    const double navIcon = 50;

    final size = MediaQuery.of(context).size;
    final double cardW = size.width * cardAspectW;
    final double cardH = size.height * cardAspectH;

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
                  const SizedBox(height: 200),

                  // 上方兩個卡片
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // 讓兩卡片集中
                    children: [
                      _LearnCard(
                        width: cardW,
                        height: cardH,
                        title: 'basic chords',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BasicChordsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 100), // 決定卡片之間距離
                      _LearnCard(
                        width: cardW,
                        height: cardH,
                        title: 'song',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SongPage()),
                          );
                        },
                      ),
                    ],
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

class _LearnCard extends StatelessWidget {
  final double width;
  final double height;
  final String title;
  final VoidCallback? onTap;
  const _LearnCard({
    required this.width,
    required this.height,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'LaBelleAurore',
            fontSize: 50,
            color: Colors.black87,
          ),
        ),
      ),
    ),
  );
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
