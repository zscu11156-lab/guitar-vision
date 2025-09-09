import 'package:flutter/material.dart';
import 'lesson1test2.dart'; // 若尚未建立 test2，暫時註解這行即可

class Lesson1TestPage extends StatefulWidget {
  const Lesson1TestPage({super.key});
  @override
  State<Lesson1TestPage> createState() => _Lesson1TestPageState();
}

class _Lesson1TestPageState extends State<Lesson1TestPage> {
  // ===== 圖片設定 =====
  static const String kImage = 'assets/images/test.png'; // 你的 test 圖片
  static const double kImageMaxWidth = 280; // 想再小就改這個值（例如 240/220）

  // ===== 正確答案（以你指定的詞）=====
  // 1: 琴頭, 2: 弦紐, 3: 琴衍, 4: 響孔, 5: 琴橋
  final Map<int, String> _answerKey = const {
    1: '琴頭',
    2: '弦紐',
    3: '琴衍',
    4: '響孔',
    5: '琴橋',
  };

  // ===== 同義詞（輸入這些也算對）=====
  final Map<String, List<String>> _aliases = const {
    '琴頭': ['琴頭', 'head'],
    '弦紐': ['弦紐', '弦鈕', '弦钮', 'tuningpeg', 'tuning pegs', '弦軸', '調音鈕'],
    '琴衍': ['琴衍', '品格', '品', 'fret'],
    '響孔': ['響孔', '音孔', 'soundhole', 'sound hole', '共鳴孔'],
    '琴橋': ['琴橋', '橋', 'bridge'],
  };

  // 使用者輸入欄位
  final Map<int, TextEditingController> _controllers = {
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
    4: TextEditingController(),
    5: TextEditingController(),
  };

  bool _submitted = false;

  // ===== 判分邏輯 =====
  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  bool _isCorrect(int k) {
    final user = _norm(_controllers[k]!.text);
    final canonical = _answerKey[k]!;
    final accepted = _aliases[canonical] ?? [canonical];
    return accepted.map(_norm).contains(user);
  }

  int get _correctCount => _controllers.keys.where(_isCorrect).length;

  int get _stars {
    // 5 題：5=3星、4=2星、3=1星、其餘0星
    final c = _correctCount;
    if (c >= 5) return 3;
    if (c == 4) return 2;
    if (c == 3) return 1;
    return 0;
  }

  void _reset() {
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() => _submitted = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _decor(int i) {
    Color border;
    if (_submitted) {
      border = _isCorrect(i) ? Colors.greenAccent : Colors.redAccent;
    } else {
      border = Colors.white24;
    }
    return InputDecoration(
      labelText: '$i.',
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0x22000000),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: border, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _field(int i) {
    return TextField(
      controller: _controllers[i],
      enabled: !_submitted,
      style: const TextStyle(color: Colors.white),
      decoration: _decor(i),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false, // 不要自動返回箭頭
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.pop(context),
          icon: Image.asset(
            'assets/images/close.png', // ← 左上改成圖片 close
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        title: const Text('Lesson 1 Test（構造配對）',
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 560; // 窄螢幕改直排
            final image = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kImageMaxWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(kImage, fit: BoxFit.contain),
                ),
              ),
            );

            final fields = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 1; i <= 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _field(i),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final allFilled = _controllers.values
                              .every((c) => c.text.trim().isNotEmpty);
                          if (!allFilled) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('還有題目沒填寫')),
                            );
                            return;
                          }
                          setState(() => _submitted = true);
                        },
                        child: const Text('交卷'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _reset,
                        child: const Text('重置'),
                      ),
                    ),
                  ],
                ),
                if (_submitted) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '答對：$_correctCount / 5',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final filled = i < _stars;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: filled ? 1.0 : 0.25, // 沒拿到星星就淡化
                          child: Image.asset(
                            'assets/images/star1.png', // 你的星星圖
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  // 下一關
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const Lesson1Test2Page(),
                          ),
                          // 如果要用你的 FlipPageRoute：
                          // FlipPageRoute(child: const Lesson1Test2Page()),
                        );
                      },
                      child: const Text('下一關'),
                    ),
                  ),
                ],
              ],
            );

            if (narrow) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    image,
                    const SizedBox(height: 16),
                    fields,
                  ],
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: image),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: fields),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
