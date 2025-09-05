import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Guitar Vision',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const SplashScreen(),
      );
}

// ── Splash 畫面 ─────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _fadeDur = Duration(milliseconds: 500);
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSplash());
  }

  Future<void> _runSplash() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _opacity = 1);

    await Future.delayed(_fadeDur);
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    setState(() => _opacity = 0);
    await Future.delayed(_fadeDur);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: _fadeDur,
            child: const Text(
              'Guitar\nVision',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'LaBelleAurore',
                fontSize: 64,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      );
}
