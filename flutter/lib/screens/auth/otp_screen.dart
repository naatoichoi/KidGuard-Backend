import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/child_auth_service.dart';
import '../parent/parent_home_screen.dart';
import '../child/child_home_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.userName});
  final String userName;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nhập đủ 6 chữ số OTP.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final role = await AuthService().verifyOtp(
        userName: widget.userName,
        code: _code.text,
      );
      if (role == 'Child') await ChildAuthService().restoreAfterOtp();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => role == 'Parent'
              ? const ParentHomeScreen()
              : const ChildHomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác minh OTP')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: Color(0xFF6254D9),
              ),
              const SizedBox(height: 16),
              Text(
                'Xác minh ${widget.userName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Nhập mã 6 chữ số đã gửi đến email phụ huynh. Mã có hiệu lực 5 phút.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Mã OTP',
                  prefixIcon: Icon(Icons.password),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: Text(_loading ? 'Đang xác minh...' : 'Xác minh'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nếu cần mã mới, quay lại đăng nhập và chờ ít nhất 60 giây.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
