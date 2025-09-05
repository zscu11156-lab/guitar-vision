import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';
import 'mic_probe.dart';
import 'login.dart'; // 👈 記得引入 LoginPage

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    // 顯示提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ 已登出")),
    );

    // 跳回登入頁，清空導航堆疊
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const double bottomBarHeight = 80;
    const double navIcon = 36;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ① 內容 ListView（下層）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                padding: const EdgeInsets.only(
                  top: 80,
                  bottom: bottomBarHeight + 24,
                ),
                children: [
                  _fullWidthButton(
                    '調音器',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MicProbePage()),
                      );
                    },
                  ),
                  _fullWidthButton('聯繫開發者', onTap: () {}),

                  // 🔑 新增登出按鈕
                  _fullWidthButton(
                    '登出',
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),

            // ② 右上叉叉
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image.asset('assets/images/close.png', width: 40),
              ),
            ),
          ],
        ),
      ),

      // BottomBar
      bottomNavigationBar: Container(
        height: bottomBarHeight,
        color: Colors.black,
        child: Row(
          children: [
            _navItem(
              'assets/images/home.png',
              navIcon,
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              },
            ),
            _navItem(
              'assets/images/tuner.png',
              navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GvTunerPage()),
                );
              },
            ),
            _navItem(
              'assets/images/chordchart.png',
              navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChordChart()),
                );
              },
            ),
            _navItem(
              'assets/images/member.png',
              navIcon,
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

  // ── 滿版文字區塊 ──
  Widget _fullWidthButton(
    String text, {
    required VoidCallback onTap,
    Color color = const Color.fromARGB(255, 223, 221, 221),
    Color textColor = Colors.black,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 70,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ),
      );

  // ── BottomBar icon ──
  Widget _navItem(String img, double size, {VoidCallback? onTap}) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(child: Image.asset(img, width: size)),
        ),
      );
}
