// song.dart（空白版面，保留主頁/設定/底部導覽列）
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'settings.dart';
import 'package:audioplayers/audioplayers.dart';
import 'tuner.dart';
import 'member.dart';

class ChordChart extends StatefulWidget {
  const ChordChart({super.key});

  @override
  State<ChordChart> createState() => _ChordChartState();
}

class _ChordChartState extends State<ChordChart> {
  // 和弦清單（保留你的原本內容；統一使用 D7_F#）
  final List<String> _chords = const [
    'Am',
    'Am7',
    'B',
    'Bm',
    'C',
    'Cadd9',
    'D',
    'D7_F#',
    'Dsus4',
    'Em',
    'Em7',
    'G',
  ];

  // 多選高亮（可刪除）
  final Set<String> _selected = {};

  // 每個和弦的圖片 / 說明 / 音檔
  // 注意：D7_F# 的檔名仍建議用 D7Fsharp.*（路徑不能含 / ）
  final Map<String, _ChordInfo> _info = const {
    'Am': _ChordInfo(
      img: 'assets/chords/Am.png',
      audio: 'audio/chords/Am.mp3',
      desc: 'A minor：常見入門和弦，音色柔和。',
    ),
    'Am7': _ChordInfo(
      img: 'assets/chords/Am7.png',
      audio: 'audio/chords/Am7.mp3',
      desc: 'A minor 7：在 Am 上加入 7 音，帶一點爵士感。',
    ),
    'B': _ChordInfo(
      img: 'assets/chords/B.png',
      audio: 'audio/chords/B.mp3',
      desc: 'B major：通常以大橫按（barre）型態彈奏。',
    ),
    'Bm': _ChordInfo(
      img: 'assets/chords/Bm.png',
      audio: 'audio/chords/Bm.mp3',
      desc: 'B minor：常見在流行/搖滾橋段。',
    ),
    'C': _ChordInfo(
      img: 'assets/chords/C.png',
      audio: 'audio/chords/C.mp3',
      desc: 'C major：最常見的基本和弦之一。',
    ),
    'Cadd9': _ChordInfo(
      img: 'assets/chords/Cadd9.png',
      audio: 'audio/chords/Cadd9.mp3',
      desc: 'C add 9：在 C 和弦加入 9 音，更明亮。',
    ),
    'D': _ChordInfo(
      img: 'assets/chords/D.png',
      audio: 'audio/chords/D.mp3',
      desc: 'D major：開放和弦，民謠常見。',
    ),
    'D7_F#': _ChordInfo(
      img: 'assets/chords/D7Fsharp.png',
      audio: 'audio/chords/D7f.mp3',
      desc: 'D7/F#：屬七轉位，常作過門使用。',
    ),
    'Dsus4': _ChordInfo(
      img: 'assets/chords/Dsus4.png',
      audio: 'audio/chords/Dsus4.mp3',
      desc: 'D sus4：暫時把 3 音抬成 4 音，緊張、期待感。',
    ),
    'Em': _ChordInfo(
      img: 'assets/chords/Em.png',
      audio: 'audio/chords/Em.mp3',
      desc: 'E minor：入門必學，開放弦音色飽滿。',
    ),
    'Em7': _ChordInfo(
      img: 'assets/chords/Em7.png',
      audio: 'audio/chords/Em7.mp3',
      desc: 'E minor 7：比 Em 再鬆一點的感覺。',
    ),
    'G': _ChordInfo(
      img: 'assets/chords/G.png',
      audio: 'audio/chords/G.mp3',
      desc: 'G major：開放弦最招牌的亮度。',
    ),
  };

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Chord',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LaBelleAurore',
                        fontSize: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 和弦格子
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.6,
                        ),
                    itemCount: _chords.length,
                    itemBuilder: (context, i) {
                      final name = _chords[i];
                      final selected = _selected.contains(name);
                      return _ChordTile(
                        name: name,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            selected
                                ? _selected.remove(name)
                                : _selected.add(name);
                          });
                          _openChordDialog(name);
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 右上：設定
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
                child: Image.asset('assets/images/Setting.png', width: 50),
              ),
            ),
          ],
        ),
      ),

      // BottomBar 導覽列（新版）
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

            // Tuner（跳調音器）
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

            // ChordChart（目前頁，不跳轉）
            const _NavItem(
              img: 'assets/images/chordchart.png',
              size: navIcon,
              onTap: null,
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

  // ───────── 彈出對話框（含圖、說明、播放） ─────────
  Future<void> _openChordDialog(String name) async {
    final info = _info[name];
    final player = AudioPlayer(); // Web/Safari：需要使用者手勢才允許播放，按鈕屬於手勢
    bool isPlaying = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 標題
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 和弦圖片
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            info != null
                                ? Image.asset(
                                  info.img,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _imgFallback(),
                                )
                                : _imgFallback(),
                      ),
                      const SizedBox(height: 12),

                      // 簡述
                      Text(
                        info?.desc ?? '尚未提供此和弦的說明。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),

                      // 播放鍵
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                (info?.audio == null)
                                    ? null
                                    : () async {
                                      if (!isPlaying) {
                                        final audioPath =
                                            info!.audio!; // String? → String
                                        await player.play(
                                          AssetSource(audioPath),
                                        );
                                        setState(() => isPlaying = true);
                                        player.onPlayerComplete.listen((_) {
                                          if (mounted)
                                            setState(() => isPlaying = false);
                                        });
                                      } else {
                                        await player.stop();
                                        setState(() => isPlaying = false);
                                      }
                                    },
                            icon: Icon(
                              isPlaying ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(isPlaying ? '停止' : '播放'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 關閉
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('關閉'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    await player.dispose(); // 釋放播放器
  }

  Widget _imgFallback() => Container(
    color: const Color(0x11FFFFFF),
    height: 220,
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_not_supported,
      color: Colors.white54,
      size: 48,
    ),
  );
}

// ── 單一和弦方塊 ──
class _ChordTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _ChordTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 資料模型 ──
class _ChordInfo {
  final String img;
  final String? audio; // 可空：沒有檔就禁用播放鍵
  final String desc;
  const _ChordInfo({
    required this.img,
    required this.audio,
    required this.desc,
  });
}

// ── 底部導覽列元件 ──
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
