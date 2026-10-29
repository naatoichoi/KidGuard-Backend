import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/guard_service.dart';

class GuardSetupScreen extends StatefulWidget {
  const GuardSetupScreen({super.key});
  @override
  State<GuardSetupScreen> createState() => _GuardSetupScreenState();
}

class _GuardSetupScreenState extends State<GuardSetupScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _status = {};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final status = await GuardService.status();
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _open(String type) async {
    try {
      await GuardService.openSettings(type);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Permission.notification.request();
      await GuardService.enable();
      await GuardService.sync();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _permission(
    String title,
    String subtitle,
    String key,
    String action,
  ) => Card(
    child: ListTile(
      leading: Icon(
        _status[key] == true ? Icons.check_circle : Icons.warning_amber,
        color: _status[key] == true ? Colors.green : Colors.orange,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: () => _open(action),
        child: const Text('Thiết lập'),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bật giới hạn trên máy trẻ')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.phonelink_lock, size: 64, color: Color(0xFF6254D9)),
        const SizedBox(height: 16),
        const Text(
          'Nhờ phụ huynh thiết lập một lần',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 16),
        _permission(
          '1. Quyền thời gian sử dụng',
          'Cho phép đo thời gian thực tế của từng ứng dụng.',
          'usageAccess',
          'usage',
        ),
        _permission(
          '2. Trợ năng KidGuard',
          'Cho phép chặn ứng dụng khi hết thời gian.',
          'accessibility',
          'accessibility',
        ),
        _permission(
          '3. Quyền quản trị thiết bị',
          'Cho phép khóa màn hình khi hết giờ tổng.',
          'deviceAdmin',
          'admin',
        ),
        const SizedBox(height: 16),
        if (_status['enabled'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Đã bật giám sát'),
          ),
        if ((_status['error'] ?? '').toString().isNotEmpty)
          Text(
            '${_status['error']}',
            style: const TextStyle(color: Colors.orange),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed:
              _busy ||
                  _status['usageAccess'] != true ||
                  _status['accessibility'] != true ||
                  _status['deviceAdmin'] != true ||
                  _status['enrolled'] != true
              ? null
              : _enable,
          icon: const Icon(Icons.shield),
          label: Text(
            _busy ? 'Đang đồng bộ…' : 'Đồng ý bật giám sát và khóa khi hết giờ',
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Kiểm tra lại quyền')),
      ],
    ),
  );
}
