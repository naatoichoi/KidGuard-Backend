
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../child/child_home_screen.dart';
import '../child/child_pairing_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _userName = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService().login(
        userName: _userName.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtpScreen(
            userName: _userName.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openRegister() async {
    final userName =
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );

    if (!mounted || userName == null) return;

    _userName.text = userName;
    _password.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đăng ký thành công! '
              'Hãy đăng nhập để nhận OTP.',
        ),
      ),
    );
  }

  Future<void> _openChildPairing() async {
    if (_loading) return;

    final paired =
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ChildPairingScreen(),
      ),
    );

    if (!mounted) return;

    if (paired == true) {
      // Ghép thành công: xóa toàn bộ màn hình
      // đăng nhập và đưa Child vào Home.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const ChildHomeScreen(),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 80,
                      color: Color(0xFF6254D9),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'KidGuard',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đồng hành cùng con '
                          'trong thế giới số',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _userName,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Nhập tên đăng nhập';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) {
                        if (!_loading) _login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                                  () => _obscure = !_obscure,
                            );
                          },
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nhập mật khẩu';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        child: Text(
                          _loading
                              ? 'Đang gửi OTP...'
                              : 'Đăng nhập',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Mã OTP sẽ được gửi '
                          'đến email phụ huynh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text(
                            'Chưa có tài khoản?',
                          ),
                        ),
                        TextButton(
                          onPressed:
                          _loading ? null : _openRegister,
                          child: const Text(
                            'Đăng ký ngay',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: Text(
                            'GHÉP THIẾT BỊ',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed:
                      _loading ? null : _openChildPairing,
                      icon: const Icon(
                        Icons.qr_code_2,
                      ),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        child: Text(
                          'Tạo mã QR cho thiết bị Child',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Dùng trên điện thoại của con. '
                          'Phụ huynh sẽ quét mã QR '
                          'để liên kết thiết bị. '
                          'Trẻ không cần tài khoản đăng nhập.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
