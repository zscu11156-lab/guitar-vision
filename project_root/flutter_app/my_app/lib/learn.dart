import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'lesson1.dart';
import 'lesson2.dart';
import 'lesson3.dart';
import 'settings.dart';
import 'homepage.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    /* ─── 1. 計算棋盤邊長 (扣 SafeArea+導覽列) ─── */
    final media = MediaQuery.of(context);
    final pad = media.padding;
    const bottomBarH = 80.0;

    final usableW = media.size.width - pad.left - pad.right;
    final usableH = media.size.height - pad.top - pad.bottom - bottomBarH;
    final boardSide = math.min(usableW, usableH) * 0.95; // ← 放大係數

    return Scaffold(
      backgroundColor: Colors.black,

      /* ─── 2. 內容區 ─── */
      body: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(width: boardSide, height: boardSide, child: _BoardLayer()),
            Align(
              // 設定齒輪
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 12),
                child: GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      ),
                  child: Image.asset('assets/images/Setting.png', width: 50),
                ),
              ),
            ),
          ],
        ),
      ),

      /* ─── 3. 底部導覽列 ─── */
      bottomNavigationBar: SafeArea(top: false, child: const _BottomNavBar()),
    );
  }
}

/* ────────────────── 棋盤 Stack ────────────────── */
class _BoardLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cst) {
        /* 基礎尺寸 */
        final side = cst.maxWidth;
        const borderRatio = 0.085; // 米色邊框比例
        final border = side * borderRatio;
        final cell = (side - 2 * border) / 8;

        Offset pos(int col, int row) =>
            Offset(border + col * cell, border + row * cell);

        /* ===== 棋子中心座標 (全落黑格) ===== */
        const pieceScale = 1.5; // 棋子寬度
        final sizePiece = cell * pieceScale;
        final centerOff = Offset(
          (cell - sizePiece) / 2,
          (cell - sizePiece) / 2,
        );
        final upShift = Offset(0, -cell * 0.3); // 這一行想改多少就調係數

        final p1 = pos(0, 7) + centerOff + upShift; // Lesson1
        final p2 =
            pos(4, 3) + centerOff + Offset(-cell * 0.5, cell * 0.5) + upShift;
        final p3 = pos(7, 0) + centerOff + upShift; // Lesson3

        /* ===== 曲線端點/控制點 ===== */
        const dash = 16.0, gap = 10.0;
        final tagH = cell * .25; // 標籤高度
        final s1 = p1 + Offset(sizePiece * .5, -tagH);
        final e1 = p2 + Offset(0, tagH / 2);
        final c1 = Offset(
          (s1.dx + e1.dx) / 2 - cell * .8,
          (s1.dy + e1.dy) / 2 - cell * 1.2,
        );

        final s2 = e1;
        final e2 = p3 + Offset(-sizePiece * .5, tagH / 4);
        final c2 = Offset(
          (s2.dx + e2.dx) / 2 + cell * .9,
          (s2.dy + e2.dy) / 2 - cell * 1.2,
        );

        return Stack(
          children: [
            /* 1️⃣ 棋盤底圖 */
            Positioned.fill(
              child: Image.asset(
                'assets/images/chessboard.png',
                fit: BoxFit.fill,
              ),
            ),

            /* 3️⃣ 棋子 + 標籤 */
            _pieceWithLabel(
              'lesson1',
              'Lesson1',
              'assets/images/lesson1.png',
              p1,
              sizePiece,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Lesson1Page()),
              ),
            ),
            _pieceWithLabel(
              'lesson2',
              'Lesson2',
              'assets/images/lesson2.png',
              p2,
              sizePiece,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Lesson2Page()),
              ),
            ),
            _pieceWithLabel(
              'lesson3',
              'Lesson3',
              'assets/images/lesson3.png',
              p3,
              sizePiece,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Lesson3Page()),
              ),
            ),
          ],
        );
      },
    );
  }

  /* ── 棋子 + 標籤元件 ── */
  Widget _pieceWithLabel(
    String keyName,
    String label,
    String img,
    Offset pos,
    double size,
    VoidCallback onTap,
  ) => Positioned(
    left: pos.dx,
    top: pos.dy,
    child: Column(
      children: [
        GestureDetector(
          key: Key(keyName),
          onTap: onTap,
          child: Image.asset(img, width: size),
        ),
        const SizedBox(height: 4),
        Container(
          width: size,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 238, 181, 75),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'LaBelleAurore',
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

/* ────────────────── 底部導覽列 ────────────────── */
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    return Container(
      height: 80,
      color: Colors.black,
      child: Row(
        children: [
          // Home
          _nav('assets/images/home.png', navIcon, () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // 若是從 Home 進來，pop 就能回去
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            }
          }),

          // Tuner（麥克風→調音器）
          _nav(
            'assets/images/tuner.png',
            navIcon,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GvTunerPage()),
            ),
          ),

          // Chord Chart（歷史→和弦字典）
          _nav(
            'assets/images/chordchart.png',
            navIcon,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChordChart()),
            ),
          ),

          // Member
          _nav(
            'assets/images/member.png',
            navIcon,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MemberPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(String img, double size, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Center(child: Image.asset(img, width: size)),
    ),
  );
}
