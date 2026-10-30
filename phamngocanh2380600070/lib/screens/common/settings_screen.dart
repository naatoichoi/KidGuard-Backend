import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/appearance_settings.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_login_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _auth = AuthService();
  final _biometric = BiometricLoginService();

  String _userName = '';
  bool _parent = false;
  bool _loading = true;
  bool _saving = false;
  bool _enrolled = false;
  bool _canBiometric = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _parent = await _auth.getValidRole() == 'Parent';
      if (_parent) {
        final profile = await _auth.getProfile();
        _userName = profile['userName']?.toString() ?? '';
        _fullName.text = profile['fullName']?.toString() ?? '';
        _email.text = profile['email']?.toString() ?? '';
        _enrolled = await _biometric.isEnrolled();
        _canBiometric = await _biometric.canUseBiometrics();
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _auth.updateProfile(
        fullName: _fullName.text,
        email: _email.text,
        currentPassword: _currentPassword.text.isEmpty
            ? null
            : _currentPassword.text,
        newPassword: _newPassword.text.isEmpty ? null : _newPassword.text,
        confirmPassword: _confirmPassword.text.isEmpty
            ? null
            : _confirmPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    try {
      if (enable) {
        final ok = await _biometric.enroll(_userName);
        if (!mounted) return;
        setState(() => _enrolled = ok);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Lần đăng nhập sau có thể dùng khuôn mặt hoặc vân tay.'
                  : 'Không bật được sinh trắc học.',
            ),
          ),
        );
      } else {
        await _biometric.disable();
        if (mounted) setState(() => _enrolled = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Giao diện', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Cỡ chữ'),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.9, label: Text('Nhỏ')),
              ButtonSegment(value: 1, label: Text('Vừa')),
              ButtonSegment(value: 1.2, label: Text('Lớn')),
            ],
            selected: {appearance.fontScale},
            onSelectionChanged: (value) => appearance.setFontScale(value.first),
          ),
          const SizedBox(height: 16),
          const Text('Màu nền'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final color in AppearanceSettings.backgrounds)
                GestureDetector(
                  onTap: () => appearance.setBackground(color),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: color,
                    child: appearance.background.toARGB32() == color.toARGB32()
                        ? Icon(
                            Icons.check,
                            color:
                                ThemeData.estimateBrightnessForColor(color) ==
                                    Brightness.dark
                                ? Colors.white
                                : const Color(0xFF6254D9),
                          )
                        : null,
                  ),
                ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 28),
            const Center(child: CircularProgressIndicator()),
          ] else if (_error != null) ...[
            const SizedBox(height: 28),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              child: const Text('Thử tải lại hồ sơ'),
            ),
          ] else if (_parent) ...[
            const SizedBox(height: 28),
            Text('Hồ sơ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _userName,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập họ tên'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (_parent && (value == null || value.trim().isEmpty)) {
                        return 'Phụ huynh cần email nhận OTP';
                      }
                      if (value != null &&
                          value.trim().isNotEmpty &&
                          !value.contains('@')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu hiện tại (khi đổi mật khẩu)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới (không bắt buộc)',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 6) {
                        return 'Mật khẩu mới tối thiểu 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                    ),
                    validator: (value) {
                      if (_newPassword.text.isNotEmpty &&
                          value != _newPassword.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: Text(_saving ? 'Đang lưu...' : 'Lưu hồ sơ'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Đăng nhập nhanh',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khuôn mặt hoặc vân tay'),
              subtitle: Text(
                _canBiometric
                    ? 'Lần đầu vẫn dùng mật khẩu và OTP. Lần sau có thể mở khóa bằng sinh trắc học.'
                    : 'Máy này chưa có khuôn mặt/vân tay. Vào cài đặt hệ thống để thêm.',
              ),
              value: _enrolled,
              onChanged: _canBiometric ? _toggleBiometric : null,
            ),
          ],
        ],
      ),
    );
  }
}
