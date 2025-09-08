// lib/song_detail.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 判斷 Web 音訊來源
import 'song.dart';

// ⬇️ 改成匯入你分成三頁的相機檔（檔名/類別請跟你實際的一致）
import 'camera2.dart';
import 'camera3.dart';
import 'camera1.dart';

class SongDetailPage extends StatefulWidget {
  final Song song;
  const SongDetailPage({super.key, required this.song});

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _autoPlay();
  }

  // 自動播放（含 Web 相容處理）
  Future<void> _autoPlay() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);

      final rel = "audio/${widget.song.audioFile}";
      if (kIsWeb) {
        // Web 用 URL 形式：assets/ 開頭
        await _player.setSourceUrl("assets/$rel");
      } else {
        await _player.setSourceAsset(rel);
      }
      await _player.resume();

      if (widget.song.chorusStart != Duration.zero) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _player.seek(widget.song.chorusStart);
      }
    } catch (e) {
      debugPrint("autoPlay error: $e");
    }
  }

  // 依歌名跳對應相機頁（三支分頁）
  Future<void> _openCameraPage() async {
    // 先停掉這頁音樂，避免與相機頁的音檔重疊
    try {
      await _player.stop();
    } catch (_) {}

    final t = widget.song.title.toLowerCase();
    Widget page;

    if (t.contains('晴天')) {
      page = const camera1();
    } else if (t.contains('好不容易')) {
      page = const camera3();
    } else if (t.contains('捲菸') || t.contains('卷菸')) {
      page = const camera2();
    } else {
      // 找不到就導到預設頁（你也可改成 Dialog 提醒）
      page = const SongPage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到對應相機頁，已導到預設頁')),
        );
      }
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.song.title,
          style: const TextStyle(
            fontFamily: 'LaBelleAurore',
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 封面圖片
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                widget.song.cover,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            // 和弦
            Text(
              "和弦：${widget.song.chords}",
              style: const TextStyle(
                fontFamily: 'LaBelleAurore',
                fontSize: 20,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // 難度
            Text(
              "難度：${widget.song.level}",
              style: const TextStyle(
                fontFamily: 'LaBelleAurore',
                fontSize: 18,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 播放提示
            const Text(
              "歌曲自動播放中...",
              style: TextStyle(
                fontFamily: 'LaBelleAurore',
                fontSize: 16,
                color: Colors.white54,
              ),
            ),

            // ✅ 按鈕推到底
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // ⬇️ 改成呼叫我們的跳轉方法
                  onPressed: _openCameraPage,
                  child: const Text("開始挑戰"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
