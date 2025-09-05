import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'member.dart';
import 'camera1.dart';
import 'song_detail.dart'; // 引入 SongDetailPage

class SongPage extends StatefulWidget {
  const SongPage({super.key});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> {
  // ---- 歌單（每首歌從 0 秒開始）----
  static const List<Song> songs = [
    Song(
      title: '周杰倫 晴天',
      chords: '(Em7 Cadd9 G D/F# Dsus4 D C B Am7)',
      level: '(困難)',
      cover: 'assets/images/song1.png',
      bgColor: Color.fromARGB(255, 245, 132, 132),
      audioFile: 'songs/song1.MP3',
      chorusStart: Duration.zero, // 從 0 秒開始
    ),
    Song(
      title: '美秀集團 捲菸',
      chords: '(C D G Em)',
      level: '(簡單)',
      cover: 'assets/images/song2.png',
      bgColor: Color.fromARGB(255, 196, 245, 182),
      audioFile: 'songs/song2.MP3',
      chorusStart: Duration.zero, // 從 0 秒開始
    ),
    Song(
      title: '告五人 好不容易',
      chords: '(G Em Bm C D B Am)',
      level: '(初階)',
      cover: 'assets/images/song3.png',
      bgColor: Color.fromARGB(255, 182, 214, 246),
      audioFile: 'songs/song3.MP3',
      chorusStart: Duration.zero, // 從 0 秒開始
    ),
  ];

  // 只紀錄星數（0~3），不做解鎖
  late final List<int> _stars = List.filled(songs.length, 0);
  int get _passedCount => _stars.where((s) => s > 0).length;

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;
    final int songCount = songs.length;
    final double progress = songCount == 0 ? 0 : _passedCount / songCount;

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
                  const SizedBox(height: 24),

                  // 標題
                  const Center(
                    child: Text(
                      'Songs',
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
                      'Practice & Challenge',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontFamily: 'LaBelleAurore',
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 進度條
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
                        '$_passedCount/$songCount',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 三格歌曲卡片
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: songCount,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final stars = _stars[index];

                      return _SongCard(
                        title: song.title,
                        chords: song.chords,
                        level: song.level,
                        stars: stars,
                        cover: AssetImage(song.cover),
                        bgColor: song.bgColor,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SongDetailPage(song: song),
                            ),
                          );
                          if (result != null && result is int) {
                            setState(() => _stars[index] = result);
                          }
                        },
                      );
                    },
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

      // 底部導覽列
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
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

// ────── 卡片元件 ──────
class _SongCard extends StatelessWidget {
  final String title;
  final String chords;
  final String level;
  final int stars;
  final VoidCallback? onTap;
  final ImageProvider? cover;
  final Color bgColor;

  const _SongCard({
    required this.title,
    required this.chords,
    required this.level,
    required this.stars,
    required this.bgColor,
    this.onTap,
    this.cover,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cover != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image(image: cover!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chords,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  level,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
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
}

// ────── 歌曲資料結構 ──────
class Song {
  final String title;
  final String chords;
  final String level;
  final String cover;
  final Color bgColor;
  final String audioFile; // 音檔路徑
  final Duration chorusStart; // 副歌起始時間

  const Song({
    required this.title,
    required this.chords,
    required this.level,
    required this.cover,
    required this.bgColor,
    required this.audioFile,
    required this.chorusStart,
  });
}

// ────── 底部導覽列元件 ──────
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
