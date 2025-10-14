import 'package:flutter/material.dart';
import 'api.dart';
import 'settings.dart';


class PingPage extends StatefulWidget {
  const PingPage({super.key});

  @override
  State<PingPage> createState() => _PingPageState();
}

class _PingPageState extends State<PingPage> {
  String _result = '尚未測試';

  Future<void> _doPing() async {
    setState(() {
      _result = '測試中...';
    });

    try {
      final res = await Api.ping();
      setState(() {
        _result = '成功：$res';
      });
    } catch (e) {
      setState(() {
        _result = '失敗：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ping 測試")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_result, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _doPing,
              child: const Text("呼叫 /ping"),
            ),
          ],
        ),
      ),
    );
  }
}
