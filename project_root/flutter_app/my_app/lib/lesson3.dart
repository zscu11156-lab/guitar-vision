import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';

class Lesson3Page extends StatefulWidget {
  const Lesson3Page({super.key});

  @override
  State<Lesson3Page> createState() => _Lesson3PageState();
}

class _Lesson3PageState extends State<Lesson3Page> {
  /* ---------- 關卡設定 ---------- */
  static const int levelCount = 9; // 想改關卡數就調這行
  final List<int> _stars = List.filled(levelCount, 0);
  final List<bool> _unlocked = List.generate(levelCount, (i) => i == 0);

  int get _passedCount => _stars.where((s) => s > 0).length;

  @override
  Widget build(BuildContext context) {
    const navIcon = 50.0;
    final progress = _passedCount / levelCount;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            /* ---------- 內容 ---------- */
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 24),

                  /* 標題 & 副標題 */
                  const Center(
                    child: Text(
                      'Lesson 3',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LaBelleAurore',
                        fontSize: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Advanced Chords', // ← 依需求修改
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontFamily: 'LaBelleAurore',
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /* 進度條 */
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_passedCount/$levelCount',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /* 關卡網格 */
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 1.3,
                        ),
                    itemCount: levelCount,
                    itemBuilder:
                        (_, index) => _LevelCard(
                          index: index,
                          unlocked: _unlocked[index],
                          stars: _stars[index],
                          onTap:
                              _unlocked[index]
                                  ? () => _openLevelBottomSheet(context, index)
                                  : null,
                        ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            /* 右上設定 */
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

      /* ---------- 底部導覽列 ---------- */
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

  /* ---------- 星數選擇底部面板 ---------- */
  void _openLevelBottomSheet(BuildContext context, int index) {
    int tempStars = _stars[index] == 0 ? 1 : _stars[index];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setSheet) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Level ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'LaBelleAurore',
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '選擇本關通關星數（可之後再挑戰刷新）',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final filled = i < tempStars;
                          return IconButton(
                            onPressed: () => setSheet(() => tempStars = i + 1),
                            iconSize: 36,
                            icon: Icon(
                              Icons.star,
                              color: filled ? Colors.amber : Colors.white24,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _stars[index] = tempStars;
                                if (index + 1 < levelCount) {
                                  _unlocked[index + 1] = true;
                                }
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('儲存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

/* ------------------- 關卡卡片 ------------------- */
class _LevelCard extends StatelessWidget {
  final int index;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;
  const _LevelCard({
    required this.index,
    required this.unlocked,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: unlocked ? onTap : null,
    child: Stack(
      children: [
        /* 卡片背景 */
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Text(
              'Lesson${index + 1}',
              style: const TextStyle(
                fontFamily: 'LaBelleAurore',
                fontSize: 24,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        /* 鎖定遮罩 */
        if (!unlocked)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.lock, color: Colors.white70, size: 36),
            ),
          ),

        /* 星星列 */
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.star,
                  size: 16,
                  color: filled ? Colors.amber : Colors.black26,
                ),
              );
            }),
          ),
        ),
      ],
    ),
  );
}

/* ------------------- 底導覽元件 ------------------- */
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
