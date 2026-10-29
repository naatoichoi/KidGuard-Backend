import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/guard_service.dart';

import '../../services/api_service.dart';
import '../../services/child_auth_service.dart';

class ChildUsageScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const ChildUsageScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<ChildUsageScreen> createState() => _ChildUsageScreenState();
}

class _ChildUsageScreenState extends State<ChildUsageScreen>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final ChildAuthService _auth = ChildAuthService();

  Timer? _timer;

  List<Map<String, dynamic>> _apps = [];
  List<Map<String, dynamic>> _limits = [];

  bool _loading = true;
  bool _busy = false;
  bool _hasPermission = false;

  String? _error;
  DateTime? _lastSync;

  static const Map<String, String> _knownApps = {
    'com.google.android.youtube': 'YouTube',
    'com.android.chrome': 'Google Chrome',
    'com.zing.zalo': 'Zalo',
    'com.facebook.katana': 'Facebook',
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readAndSync();
    }
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _appName(String packageName) {
    final label = _apps
        .where((app) => app['packageName'] == packageName)
        .firstOrNull?['appName']
        ?.toString()
        .trim();
    return label == null || label.isEmpty
        ? (_knownApps[packageName] ?? packageName)
        : label;
  }

  Future<void> _initialize() async {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    await _loadLimits();
    await _readAndSync();

    if (!mounted) return;

    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _readAndSync());

    setState(() {
      _loading = false;
    });
  }

  Future<void> _requestUsagePermission() async {
    await GuardService.openSettings('usage');
  }

  Future<void> _loadLimits() async {
    try {
      final refreshed = await _auth.refreshToken();

      if (!refreshed) {
        throw Exception('Không thể xác thực Child.');
      }

      final response = await _api.get(
        'ScreenTime/limits/status/${widget.deviceId}',
      );

      if (!mounted) return;

      setState(() {
        _limits = ((response as Map)['limits'] as List)
            .map(
              (item) => {
                ...Map<String, dynamic>.from(item as Map),
                'isEnabled': true,
              },
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Không tải được giới hạn: $e';
      });
    }
  }

  Future<void> _readAndSync() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final allowed = (await GuardService.status())['usageAccess'] == true;
      if (allowed != true) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _error = 'Chưa cấp quyền Usage Access cho KidGuard trên máy Child.';
          });
        }
        return;
      }

      final snapshot = await GuardService.usageSnapshot();
      final apps = (snapshot['apps'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _hasPermission = true;
        _apps = apps;
        _error = apps.isEmpty
            ? 'Android chưa trả về thời gian sử dụng hôm nay. '
                  'Hãy dùng một ứng dụng rồi quay lại để đồng bộ.'
            : null;
      });
      if (apps.isEmpty) return;

      final total = apps.fold<int>(
        0,
        (sum, app) => sum + _toInt(app['durationSeconds']),
      );
      if (total > 86400) {
        if (mounted) {
          setState(
            () => _error = 'Android trả về tổng thời gian trên 24 giờ; backend từ chối đồng bộ.',
          );
        }
        return;
      }

      final refreshed = await _auth.refreshToken();
      if (!refreshed) throw Exception('Không xác thực được tài khoản Child.');

      final usageDate = snapshot['usageDate'];
      await _api.post(
        'ScreenTime/sync',
        body: {
          'deviceId': widget.deviceId,
          'usageDate': usageDate,
          'apps': apps,
        },
      );
      if (mounted) {
        setState(() {
          _lastSync = DateTime.now();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Đọc hoặc đồng bộ thất bại: $e';
        });
      }
    } finally {
      _busy = false;
    }
  }

  int get _totalSeconds {
    return _apps.fold<int>(
      0,
      (sum, app) => sum + _toInt(app['durationSeconds']),
    );
  }

  int _usedSecondsFor(String packageName) {
    return _apps
        .where((app) => app['packageName'] == packageName)
        .fold<int>(0, (sum, app) => sum + _toInt(app['durationSeconds']));
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;

    if (hours > 0) {
      return '$hours giờ $minutes phút $remaining giây';
    }

    if (minutes > 0) {
      return '$minutes phút $remaining giây';
    }

    return '$remaining giây';
  }

  Widget _buildLimitCard(Map<String, dynamic> limit) {
    final type = limit['limitType']?.toString().toUpperCase() ?? '';

    final packageName = limit['packageName']?.toString() ?? '';

    final minutes = _toInt(
      limit['effectiveLimitMinutes'] ?? limit['dailyLimitMinutes'],
    );

    final enabled = limit['isEnabled'] == true;

    final usedSeconds = type == 'TOTAL'
        ? _totalSeconds
        : _usedSecondsFor(packageName);

    final maxSeconds = minutes * 60;

    final progress = maxSeconds > 0
        ? (usedSeconds / maxSeconds).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final remaining = maxSeconds - usedSeconds;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEAE7FF),
                  child: Icon(
                    type == 'TOTAL' ? Icons.timer_outlined : Icons.apps,
                    color: const Color(0xFF6254D9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'TOTAL'
                            ? 'Tổng thời gian sử dụng'
                            : _appName(packageName),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('$minutes phút/ngày'),
                    ],
                  ),
                ),
                const Icon(Icons.lock_outline, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 14),
            Text('Đã dùng: ${_formatDuration(usedSeconds)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
              color: enabled && usedSeconds >= maxSeconds
                  ? Colors.red
                  : const Color(0xFF6254D9),
            ),
            const SizedBox(height: 8),
            Text(
              !enabled
                  ? 'Giới hạn đã tắt'
                  : remaining > 0
                  ? 'Còn lại: ${_formatDuration(remaining)}'
                  : 'Đã hết thời gian sử dụng',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled && remaining <= 0 ? Colors.red : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageView() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadLimits();
        await _readAndSync();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.deviceName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Tổng thời gian sử dụng'),
                  const SizedBox(height: 12),
                  Text(
                    _formatDuration(_totalSeconds),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6254D9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${_apps.length} ứng dụng'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          if (!_hasPermission)
            FilledButton.icon(
              onPressed: _requestUsagePermission,
              icon: const Icon(Icons.settings),
              label: const Text('Cấp quyền thời gian sử dụng'),
            ),
          if (_lastSync != null)
            Text(
              'Đã đồng bộ lúc '
              '${_lastSync!.hour.toString().padLeft(2, '0')}:'
              '${_lastSync!.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _readAndSync,
            icon: const Icon(Icons.sync),
            label: const Text('Đồng bộ danh sách & thời gian'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Giới hạn phụ huynh đã đặt',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_limits.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Chưa có giới hạn đang bật.'),
              ),
            )
          else
            ..._limits.map(_buildLimitCard),
          const SizedBox(height: 24),
          const Text(
            'Danh sách ứng dụng',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._apps.map((app) {
            final packageName = app['packageName']?.toString() ?? '';

            return Card(
              child: ListTile(
                leading: const Icon(Icons.apps, color: Color(0xFF6254D9)),
                title: Text(_appName(packageName)),
                subtitle: Text(packageName),
                trailing: Text(_formatDuration(_toInt(app['durationSeconds']))),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thời gian sử dụng'),
        actions: [
          IconButton(onPressed: _initialize, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildUsageView(),
    );
  }
}
