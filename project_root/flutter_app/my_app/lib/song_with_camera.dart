import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// ───────────────────────────────
/// 主頁：歌曲內容 + 相機疊加
/// ───────────────────────────────
class SongWithCameraOverlay extends StatefulWidget {
  const SongWithCameraOverlay({super.key});

  @override
  State<SongWithCameraOverlay> createState() => _SongWithCameraOverlayState();
}

class _SongWithCameraOverlayState extends State<SongWithCameraOverlay> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final cam = _cameras.first; // 預設用第一個鏡頭（通常是後鏡頭）
      _controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint("相機初始化失敗: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "周杰倫 - 晴天",
          style: TextStyle(
            fontFamily: 'LaBelleAurore',
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── 歌曲內容 (歌詞 + 和弦) ──
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "和弦進行：Em7  Cadd9  G  D/F#",
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'LaBelleAurore',
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    """
故事的小黃花
從出生那年就飄著
童年的盪鞦韆
隨記憶一直晃到現在

風吹的很涼爽
雨下的好安靜
天青色等煙雨
而我在等你...
                    """,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 100), // 預留底部空間
                ],
              ),
            ),
          ),

          // ── 相機疊加 ──
          if (isReady)
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CameraFullScreenPage(controller: _controller!),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 160,
                    height: 120,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            )
          else
            const Positioned(
              right: 16,
              bottom: 16,
              child: SizedBox(
                width: 160,
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// ───────────────────────────────
/// 相機全螢幕頁面
/// ───────────────────────────────
class CameraFullScreenPage extends StatelessWidget {
  final CameraController controller;
  const CameraFullScreenPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller)),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
