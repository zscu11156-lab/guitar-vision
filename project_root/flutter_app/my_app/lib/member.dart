import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';

class MemberPage extends StatelessWidget {
  const MemberPage({super.key});

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
                      'Guitar\nVision',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LaBelleAurore',
                        fontSize: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── 頭像 (member.png) ──
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.transparent, // 若想灰底改 0xffd9d9d9
                      child: Image.asset(
                        'assets/images/member.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 帳號/密碼欄
                  const _InputLabel(label: '帳號：'),
                  const _InputLabel(label: '密碼：'),
                  const _InputLabel(label: '二次驗證密碼：'),
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
            // Member（當前頁，不動作）
            const _NavItem(
              img: 'assets/images/member.png',
              size: navIcon,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 小元件 ---------- //

class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16), // 整段上下留白
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // 文字
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'LaBelleAurore',
          ),
        ),
        const SizedBox(height: 10), // 與線的間距
        const Divider(
          // 白線
          color: Colors.white,
          thickness: 1.2, // 看得更清楚
          height: 1, // 不再吃額外空間
        ),
      ],
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
