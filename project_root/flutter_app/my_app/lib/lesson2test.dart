import 'package:flutter/material.dart';
import 'learn.dart'; // 回到 LearnPage

class Lesson2TestPage extends StatefulWidget {
  const Lesson2TestPage({super.key});
  @override
  State<Lesson2TestPage> createState() => _Lesson2TestPageState();
}

class _Lesson2TestPageState extends State<Lesson2TestPage> {
  // 圖片：le2 test2（檔名含空白 OK）
  static const String kImage = 'assets/images/le2 test2.png';
  static const double kImageMaxWidth = 280; // 想更小就調這裡

  // 題目標籤（只有 1~6）
  final List<String> _labels = const ['1', '2', '3', '4', '5', '6'];

  // 正確答案（依序）：Am, B, C, Cadd9, Em, G
  final Map<String, String> _answerKey = const {
    '1': 'Am',
    '2': 'B',
    '3': 'C',
    '4': 'Cadd9',
    '5': 'Em',
    '6': 'G',
  };

  final Map<String, TextEditingController> _controllers = {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final k in _labels) {
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

  // 忽略大小寫與空白
  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  bool _isCorrect(String key) {
    final user = _norm(_controllers[key]!.text);
    final ans = _norm(_answerKey[key] ?? '');
    return user.isNotEmpty && ans.isNotEmpty && user == ans;
  }

  int get _correctCount => _labels.where(_isCorrect).length;

  int get _stars {
    // 6題：6=★3、5=★2、4=★1
    final c = _correctCount;
    if (c >= 6) return 3;
    if (c == 5) return 2;
    if (c == 4) return 1;
    return 0;
  }

  void _reset() {
    for (final c in _controllers.values) c.clear();
    setState(() => _submitted = false);
  }

  InputDecoration _decor(String key) {
    final bool ok = _isCorrect(key);
    final Color border = _submitted
        ? (ok ? Colors.greenAccent : Colors.redAccent)
        : Colors.white24;
    return InputDecoration(
      labelText: '$key.',
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

  Widget _field(String key) {
    return TextField(
      controller: _controllers[key],
      enabled: !_submitted,
      maxLength: 10, // Cadd9 也夠用
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
      decoration: _decor(key).copyWith(counterText: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // 不顯示預設返回箭頭
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.pop(context),
          icon: Image.asset(
            'assets/images/close.png', // 左上自訂關閉圖
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        title: const Text('Lesson 2 Test'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左：考圖
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
              // 右：填答
              Flexible(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '請輸入對應和弦（大小寫/空白皆可）',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      for (final k in _labels)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _field(k),
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
                                final allFilled = _labels.every(
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
                            '答對：$_correctCount / ${_labels.length}',
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
                        // 回到 Learn
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
                                    builder: (_) => const LearnPage()),
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
