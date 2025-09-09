import 'package:flutter/material.dart';
import 'learn.dart'; // ← 直接回到 LearnPage 用

class Lesson1Test2Page extends StatefulWidget {
  const Lesson1Test2Page({super.key});
  @override
  State<Lesson1Test2Page> createState() => _Lesson1Test2PageState();
}

class _Lesson1Test2PageState extends State<Lesson1Test2Page> {
  // 調這個就能改圖片大小
  static const double kImageMaxWidth = 280;
  static const String kImage = 'assets/images/test2.png';

  // 答案（不分大小寫）
  final Map<String, String> _answerKey = const {
    '1': 'D',
    '2': 'A',
    '3': 'E',
    '4': 'G',
    '5': 'B',
    '6': 'E',
    'a': 'E',
    'b': 'A',
    'c': 'D',
    'd': 'G',
    'e': 'B',
    'f': 'E',
  };

  late final List<String> _keys;
  final Map<String, TextEditingController> _controllers = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _keys = ['1', '2', '3', '4', '5', '6', 'a', 'b', 'c', 'd', 'e', 'f'];
    for (final k in _keys) {
      _controllers[k] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _norm(String s) => s.trim().toUpperCase();

  bool _isCorrect(String key) {
    final user = _norm(_controllers[key]!.text);
    final ans = _norm(_answerKey[key] ?? '');
    return user.isNotEmpty && user == ans;
  }

  int get _correctCount => _keys.where(_isCorrect).length;

  int get _stars {
    final c = _correctCount; // 12 題
    if (c >= 12) return 3;
    if (c >= 10) return 2;
    if (c >= 8) return 1;
    return 0;
  }

  void _reset() {
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() => _submitted = false);
  }

  InputDecoration _decorationFor(String label, String key) {
    Color border;
    if (_submitted) {
      border = _isCorrect(key) ? Colors.greenAccent : Colors.redAccent;
    } else {
      border = Colors.white24;
    }
    return InputDecoration(
      labelText: label,
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

  Widget _field(String label, String key) {
    return TextField(
      controller: _controllers[key],
      enabled: !_submitted,
      maxLength: 1,
      style: const TextStyle(color: Colors.white),
      textAlign: TextAlign.center,
      decoration: _decorationFor(label, key).copyWith(counterText: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false, // 不要預設返回箭頭
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
        title: const Text('Lesson 1 Test 2（指板配對）'),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側：圖片（可用 kImageMaxWidth 控制）
              Flexible(
                flex: 3,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kImageMaxWidth),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(kImage, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 右側：輸入欄位
              Flexible(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('請輸入對應字母（可小寫）',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),

                      // 區塊 1: 1~6
                      const Text('數字題（1–6）',
                          style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      for (final k in ['1', '2', '3', '4', '5', '6'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _field('$k.', k),
                        ),

                      const SizedBox(height: 8),
                      // 區塊 2: a~f
                      const Text('字母題（a–f）',
                          style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      for (final k in ['a', 'b', 'c', 'd', 'e', 'f'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _field('$k.', k),
                        ),

                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                final allFilled = _keys.every(
                                  (k) =>
                                      _controllers[k]!.text.trim().isNotEmpty,
                                );
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                            '答對：$_correctCount / 12',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final filled = i < _stars;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
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
                        // 直接回到 LearnPage（清空堆疊）
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
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LearnPage(),
                                ),
                                (route) => false,
                              );
                            },
                            child: const Text('回到 Learn'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
