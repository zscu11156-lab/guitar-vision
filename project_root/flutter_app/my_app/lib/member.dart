import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'homepage.dart';
import 'settings.dart';
import 'tuner.dart';
import 'chordchart.dart';
import 'login.dart';

class MemberPage extends StatelessWidget {
  const MemberPage({super.key});

  Future<Map<String, dynamic>?> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};
    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'username': data['username'] ?? '(未設定)',
      'createdAt': data['createdAt'],
    };
  }

  @override
  Widget build(BuildContext context) {
    const double navIcon = 50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListView(
                children: [
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      'Guitar\nVision',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LaBelleAurore',
                        fontSize: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.transparent,
                      child: Image.asset(
                        'assets/images/member.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _loadProfile(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        );
                      }

                      // 尚未登入
                      if (!snap.hasData || snap.data == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _InputLabel(label: '尚未登入'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                  (_) => false,
                                );
                              },
                              child: const Text('前往登入'),
                            ),
                          ],
                        );
                      }

                      final data = snap.data!;
                      final email = (data['email'] as String?) ?? '';
                      final username = (data['username'] as String?) ?? '(未設定)';
                      final uid = (data['uid'] as String?) ?? '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(label: '帳號（Email）', value: email),
                          _Field(label: '暱稱（Username）', value: username),
                          _Field(label: 'UID', value: uid),
                          const SizedBox(height: 24),

                          // 👉 改密碼區塊（已登入）
                          _ChangePasswordCard(email: email),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // 右上設定
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
                child: Image.asset('assets/images/Setting.png', width: 50),
              ),
            ),
          ],
        ),
      ),

      // 底部導覽列（新版）
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          children: [
            _NavItem(
              img: 'assets/images/home.png',
              size: navIcon,
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              },
            ),
            _NavItem(
              img: 'assets/images/tuner.png',
              size: navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GvTunerPage()),
                );
              },
            ),
            _NavItem(
              img: 'assets/images/chordchart.png',
              size: navIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChordChart()),
                );
              },
            ),
            const _NavItem(
              img: 'assets/images/member.png',
              size: navIcon,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 改密碼卡片 ---------- //

class _ChangePasswordCard extends StatefulWidget {
  final String email;
  const _ChangePasswordCard({required this.email});

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cur = _curCtrl.text;
    final newPwd = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (newPwd.length < 6) {
      _toast("❌ 新密碼至少 6 碼");
      return;
    }
    if (newPwd != confirm) {
      _toast("❌ 新密碼與確認不一致");
      return;
    }

    setState(() => _busy = true);
    try {
      // 1) 先 re-auth（Email/Password）
      final cred = EmailAuthProvider.credential(
        email: widget.email,
        password: cur,
      );
      await user.reauthenticateWithCredential(cred);

      // 2) 更新密碼
      await user.updatePassword(newPwd);

      _toast("✅ 已更新密碼");
      _curCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          _toast('❌ 目前密碼錯誤');
          break;
        case 'weak-password':
          _toast('❌ 新密碼強度不足（至少 6 碼）');
          break;
        case 'requires-recent-login':
          _toast('⚠️ 需要重新登入後才能修改密碼');
          break;
        case 'too-many-requests':
          _toast('⚠️ 嘗試過多，請稍後再試');
          break;
        default:
          _toast('❌ 變更密碼失敗：${e.code}');
      }
    } catch (e) {
      _toast('❌ 變更密碼失敗：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendResetEmail() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
      _toast('📧 已寄出重設密碼信到：${widget.email}');
    } on FirebaseAuthException catch (e) {
      _toast('❌ 寄信失敗：${e.code}');
    } catch (e) {
      _toast('❌ 寄信失敗：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('變更密碼',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          _pwField(controller: _curCtrl, label: '目前密碼'),
          const SizedBox(height: 12),
          _pwField(controller: _newCtrl, label: '新密碼（至少 6 碼）'),
          const SizedBox(height: 12),
          _pwField(controller: _confirmCtrl, label: '確認新密碼'),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('更新密碼'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 備用：寄送重設密碼信
          TextButton(
            onPressed: _busy ? null : _sendResetEmail,
            child: const Text('改用 Email 重設密碼',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _pwField(
      {required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ---------- 小元件 ---------- //

class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'LaBelleAurore',
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white, thickness: 1.2, height: 1),
          ],
        ),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(value,
                  style: const TextStyle(color: Colors.black, fontSize: 16)),
            ),
          ],
        ),
      );
}

class _NavItem extends StatelessWidget {
  final String img;
  final double size;
  final VoidCallback? onTap;
  const _NavItem({required this.img, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(child: Image.asset(img, width: size)),
        ),
      );
}
