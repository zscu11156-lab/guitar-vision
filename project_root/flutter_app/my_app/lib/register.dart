import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      // 建立帳號
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // Firestore 寫入
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': DateTime.now(),
      });

      // 先顯示訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 註冊成功，請登入")),
        );
      }

      // 延遲 1 秒再返回登入頁，確保訊息顯示
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 註冊失敗：$e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final maxW = math.min(480.0, c.maxWidth * 0.9);
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
                            '註冊帳號',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _label('使用者名稱'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _usernameController,
                            hint: "輸入名稱",
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '請輸入名稱'
                                : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          _label('Email'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _emailController,
                            hint: "輸入 Email",
                            validator: (v) => (v == null || !v.contains("@"))
                                ? '請輸入正確的 Email'
                                : null,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: 20),
                          _label('密碼'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _passwordController,
                            hint: "輸入密碼",
                            obscure: true,
                            validator: (v) =>
                                (v == null || v.length < 6) ? '密碼至少 6 碼' : null,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _register(),
                            autofillHints: const [AutofillHints.password],
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: _register,
                              child: const Text("註冊"),
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
