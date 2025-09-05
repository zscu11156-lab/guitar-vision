// lib/mic_probe.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

const _mic = EventChannel('gv.tuner/audioStream'); // 你的 EventChannel 名稱

class MicProbePage extends StatefulWidget {
  const MicProbePage({super.key});
  @override
  State<MicProbePage> createState() => _MicProbePageState();
}

class _MicProbePageState extends State<MicProbePage> {
  StreamSubscription? _sub;
  bool _listening = false;

  // UI 指標
  double _dbfs = -120; // 目前音量（dBFS）
  double _dbfsEma = -120; // 平滑後音量
  final double _alpha = 0.25; // EMA 係數
  int _packets = 0; // 收到的封包數
  int _lastFrameBytes = 0; // 最新一包 bytes
  int _bytesThisSec = 0; // 本秒收到的總位元組
  int _bps = 0; // 每秒位元組（bytes/s）
  Timer? _secTimer;
  DateTime _lastUi = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Future<void> _start() async {
    // 要先請麥克風權限
    final granted = await Permission.microphone.request().isGranted;
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要麥克風權限才能測試')));
      return;
    }

    if (_listening) return;
    _listening = true;

    // 每秒統計一次吞吐量
    _secTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _bps = _bytesThisSec;
        _bytesThisSec = 0;
      });
    });

    _sub = _mic.receiveBroadcastStream().listen(
      _onData,
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('讀取音訊失敗：$e')));
      },
      onDone: () {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('音訊串流已結束')));
      },
      cancelOnError: false,
    );
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    _secTimer?.cancel();
    _secTimer = null;
  }

  void _onData(dynamic chunk) {
    if (chunk is! Uint8List || chunk.isEmpty) return;

    _packets++;
    _lastFrameBytes = chunk.lengthInBytes;
    _bytesThisSec += chunk.lengthInBytes;

    // 把 Int16 little-endian 轉 sample，計算 RMS
    final bd = chunk.buffer.asByteData(
      chunk.offsetInBytes,
      chunk.lengthInBytes,
    );
    double sumsq = 0;
    int count = 0;
    for (int i = 0; i + 1 < bd.lengthInBytes; i += 2) {
      final s = bd.getInt16(i, Endian.little).toDouble();
      sumsq += s * s;
      count++;
    }
    if (count == 0) return;

    // 正規化到 [-1,1] 後的 RMS
    final rms = math.sqrt(sumsq / count) / 32768.0;
    // 轉 dBFS（0 dBFS = 全尺度，安靜會趨近 -inf；這裡夾到 -120）
    final db = 20 * math.log(rms + 1e-12) / math.ln10; // 避免 log(0)
    final dbClamped = db.isFinite ? db.clamp(-120.0, 0.0) as double : -120.0;

    // 簡單 EMA 平滑
    _dbfsEma = (_dbfsEma == -120)
        ? dbClamped
        : (_alpha * dbClamped + (1 - _alpha) * _dbfsEma);
    _dbfs = _dbfsEma;

    // 降低 setState 頻率（每 50ms 更新一次 UI）
    final now = DateTime.now();
    if (now.difference(_lastUi).inMilliseconds >= 50) {
      _lastUi = now;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool receiving = _bps > 0; // 一秒內有資料就代表真的在收

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mic Probe', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _Tag(
                  text: _listening ? 'LISTENING' : 'STOPPED',
                  color: _listening ? Colors.lightBlue : Colors.grey,
                ),
                const SizedBox(width: 8),
                _Tag(
                  text: receiving ? 'RECEIVING' : 'NO SIGNAL',
                  color: receiving ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 音量表（dBFS：-120..0 轉為 0..1）
            _Meter(dbfs: _dbfs),

            const SizedBox(height: 12),
            Text(
              '${_dbfs.toStringAsFixed(1)} dBFS',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const SizedBox(height: 24),
            _StatRow(label: 'Packets', value: '$_packets'),
            _StatRow(label: 'Last frame', value: '$_lastFrameBytes bytes'),
            _StatRow(
              label: 'Throughput',
              value: _bps == 0
                  ? '0 B/s'
                  : '${(_bps / 1024).toStringAsFixed(1)} KB/s  ·  ~${(_bps / 2).toStringAsFixed(0)} samples/s',
            ),

            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _listening ? null : _start,
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _listening ? _stop : null,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  final double dbfs; // -120..0
  const _Meter({required this.dbfs});

  @override
  Widget build(BuildContext context) {
    // 把 -60..0 dBFS 映射到 0..1，低於 -60 視為 0
    final d = dbfs.clamp(-60.0, 0.0);
    final v = (d + 60) / 60.0; // 0..1

    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            color: dbfs > -6
                ? Colors.redAccent
                : dbfs > -18
                    ? Colors.orangeAccent
                    : Colors.greenAccent,
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
