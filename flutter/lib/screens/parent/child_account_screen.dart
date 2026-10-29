import 'package:flutter/material.dart';

class ChildAccountScreen extends StatefulWidget {
  const ChildAccountScreen({
    super.key,
    this.existingName,
    this.existingUserName,
  });
  final String? existingName;
  final String? existingUserName;
  @override
  State<ChildAccountScreen> createState() => _ChildAccountScreenState();
}

class _ChildAccountScreenState extends State<ChildAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void initState() {
    super.initState();
    _name.text = widget.existingName ?? '';
    _user.text = widget.existingUserName ?? '';
  }

  @override
  void dispose() {
    for (final controller in [_name, _user, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.existingName == null
            ? 'Đăng ký tài khoản cho con'
            : 'Tài khoản đăng nhập của con',
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.child_care,
                  size: 70,
                  color: Color(0xFF6254D9),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Họ và tên con'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Nhập họ tên con'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _user,
                  maxLength: 50,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập của con',
                  ),
                  validator: (value) =>
                      RegExp(r'^[a-zA-Z0-9._@+\-]{3,50}$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Dùng 3–50 ký tự: chữ không dấu, số, . _ @ + -',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  maxLength: 100,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu của con',
                  ),
                  validator: (value) =>
                      value != null &&
                          value.length >= 6 &&
                          RegExp('[a-z]').hasMatch(value) &&
                          RegExp('[0-9]').hasMatch(value)
                      ? null
                      : 'Ít nhất 6 ký tự, có chữ thường và số',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  maxLength: 100,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Xác nhận mật khẩu',
                  ),
                  validator: (value) =>
                      value == _password.text ? null : 'Mật khẩu không khớp',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    Navigator.pop(context, <String, String>{
                      'childName': _name.text.trim(),
                      'userName': _user.text.trim(),
                      'password': _password.text,
                      'confirmPassword': _confirm.text,
                    });
                  },
                  child: Text(
                    widget.existingName == null
                        ? 'Tạo tài khoản và ghép thiết bị'
                        : 'Lưu tài khoản của con',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
