import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/api_config.dart';
import '../../services/api_connection_service.dart';
import '../../services/auth_service.dart';

class ApiConnectionScreen extends StatefulWidget {
  const ApiConnectionScreen({super.key});
  @override
  State<ApiConnectionScreen> createState() => _ApiConnectionScreenState();
}

class _ApiConnectionScreenState extends State<ApiConnectionScreen> {
  final _url = TextEditingController(text: ApiConfig.baseUrl);
  final _connection = ApiConnectionService();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _url.dispose();
    _connection.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final normalized = await _connection.check(_url.text);
      final changed = normalized != ApiConfig.baseUrl;
      if (changed) {
        await const MethodChannel('kidguard/guard')
            .invokeMethod('pauseNetwork');
        await ApiConfig.save(normalized);
        await AuthService().logout();
        await const FlutterSecureStorage().write(
          key: 'kidguard_signed_out',
          value: 'true',
        );
      }
      if (mounted) Navigator.pop(context, changed);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = error is FormatException ? error.message : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kết nối máy chủ')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link, size: 64, color: Color(0xFF6254D9)),
              const SizedBox(height: 24),
              TextField(
                controller: _url,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Link backend',
                  hintText: 'https://ten-link.conveyor.cloud',
                  helperText: 'Dán Internet URL từ Conveyor',
                ),
                onSubmitted: (_) {
                  if (!_saving) _save();
                },
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang kiểm tra…' : 'Kiểm tra và lưu'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
