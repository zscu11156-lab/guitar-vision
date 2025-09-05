import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register.dart';
import 'homepage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _acc = TextEditingController();
  final _pwd = TextEditingController();

  @override
  void dispose() {
    _acc.dispose();
    _pwd.dispose();
    super.dispose();
  }

  /// 🔑 Firebase 登入
  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final acc = _acc.text.trim();
    final pwd = _pwd.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: acc,
        password: pwd,
      );

      if (mounted) {
        FocusScope.of(context).unfocus();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("登入失敗: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // 點空白收鍵盤
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final maxW = math.min(480.0, c.maxWidth * 0.9); // 自適應寬度
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Guitar\nVision',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'LaBelleAurore',
                              fontSize: 64,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 48),

                          _label('帳號'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _acc,
                            hint: '輸入 Email',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '請輸入帳號'
                                : null,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                          ),
                          const SizedBox(height: 20),

                          _label('密碼'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _pwd,
                            hint: '輸入密碼',
                            obscure: true,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? '請輸入密碼' : null,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            autofillHints: const [AutofillHints.password],
                          ),
                          const SizedBox(height: 28),

                          // Login
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: _login,
                              child: const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Register
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterPage()),
                                );
                              },
                              child: const Text('Register'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(color: Colors.white70),
        textAlign: TextAlign.left,
      );

  Widget _input({
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    void Function(String)? onSubmitted,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
}
