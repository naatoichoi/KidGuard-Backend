
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';
import '../../services/child_auth_service.dart';
import '../common/notifications_screen.dart';
import 'child_location_screen.dart';
import 'child_pairing_screen.dart';
import 'child_usage_screen.dart';
import 'request_extra_time_screen.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  final ApiService _api = ApiService();
  final ChildAuthService _childAuth = ChildAuthService();
  final FlutterSecureStorage _storage =
  const FlutterSecureStorage();

  Map<String, dynamic>? _dashboard;

  bool _loading = true;
  bool _paired = false;
  bool _syncingLocation = false;

  String? _error;
  String? _locationMessage;

  int _deviceId = 0;
  String _deviceName = 'Thiết bị';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> _refreshChildToken() async {
    try {
      return await _childAuth.refreshToken();
    } catch (_) {
      return false;
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _locationMessage = null;
    });

    try {
      // Kiểm tra thiết bị đã ghép hay chưa.
      final hasDevice = await _childAuth.hasPairedDevice();

      if (!hasDevice) {
        if (!mounted) return;

        setState(() {
          _paired = false;
          _dashboard = null;
          _deviceId = 0;
          _loading = false;
        });

        return;
      }

      // Tự cấp JWT mới khi mở màn hình Child.
      final refreshed = await _refreshChildToken();

      if (!refreshed) {
        if (!mounted) return;

        setState(() {
          _paired = true;
          _loading = false;
          _error =
          'Không thể xác thực thiết bị. '
              'Kiểm tra kết nối mạng rồi thử lại.';
        });

        return;
      }

      final token = await _storage.read(
        key: 'kidguard_jwt',
      );

      final savedDeviceId = await _storage.read(
        key: 'kidguard_device_id',
      );

      final savedDeviceName = await _storage.read(
        key: 'kidguard_device_name',
      );

      final deviceId = _toInt(savedDeviceId);

      if (token == null ||
          token.isEmpty ||
          deviceId <= 0) {
        if (!mounted) return;

        setState(() {
          _paired = true;
          _loading = false;
          _error = 'Thiếu thông tin xác thực Child.';
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        _deviceId = deviceId;
        _deviceName = savedDeviceName ?? 'Thiết bị';
        _paired = true;
      });

      // Lấy dữ liệu Dashboard.
      await _loadDashboard(refreshToken: false);

      // Tự đồng bộ GPS một lần khi mở Child Home.
      await _syncLocation(refreshToken: false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadDashboard({
    bool refreshToken = true,
  }) async {
    if (!_paired || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (refreshToken) {
        final refreshed = await _refreshChildToken();

        if (!refreshed) {
          throw Exception(
            'Không thể cấp lại JWT. '
                'Vui lòng kiểm tra kết nối mạng.',
          );
        }
      }

      final response = await _api.get(
        'Dashboard/child',
      );

      if (!mounted) return;

      setState(() {
        _dashboard = Map<String, dynamic>.from(
          response as Map,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncLocation({
    bool refreshToken = true,
  }) async {
    if (!_paired ||
        _deviceId <= 0 ||
        _syncingLocation) {
      return;
    }

    _syncingLocation = true;

    if (mounted) {
      setState(() {
        _locationMessage = 'Đang cập nhật vị trí...';
      });
    }

    try {
      final enabled =
      await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw Exception('GPS đang tắt.');
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Ứng dụng chưa được cấp quyền vị trí.',
        );
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      // Nếu người dùng mở app lâu, lấy JWT mới
      // trước khi gọi API vị trí.
      if (refreshToken) {
        final refreshed = await _refreshChildToken();

        if (!refreshed) {
          throw Exception(
            'Không thể xác thực thiết bị để gửi GPS.',
          );
        }
      }

      await _api.post(
        'Locations/sync',
        body: {
          'deviceId': _deviceId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'recordedAt':
          position.timestamp.toUtc().toIso8601String(),
          'source': 'FUSED',
        },
      );

      if (!mounted) return;

      setState(() {
        _locationMessage =
        'Đã cập nhật vị trí thành công.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationMessage =
        'Chưa cập nhật được vị trí: $e';
      });
    } finally {
      _syncingLocation = false;
    }
  }

  Future<void> _openPairing() async {
    final result =
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ChildPairingScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _initialize();
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _openLocation(
      Map<String, dynamic> device,
      ) async {
    final deviceId = _toInt(device['deviceId']);

    if (deviceId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID thiết bị không hợp lệ.'),
        ),
      );
      return;
    }

    final refreshed = await _refreshChildToken();

    if (!refreshed) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xác thực thiết bị.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildLocationScreen(
          deviceId: deviceId,
          deviceName:
          device['deviceName']?.toString() ??
              'Thiết bị',
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _openUsage(
      Map<String, dynamic> device,
      ) async {
    final deviceId = _toInt(device['deviceId']);

    if (deviceId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID thiết bị không hợp lệ.'),
        ),
      );
      return;
    }

    final refreshed = await _refreshChildToken();

    if (!refreshed) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xác thực thiết bị.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildUsageScreen(
          deviceId: deviceId,
          deviceName:
          device['deviceName']?.toString() ??
              'Thiết bị',
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _openRequestScreen(
      Map<String, dynamic> device,
      ) async {
    final deviceId = _toInt(device['deviceId']);

    final limitId =
    _toInt(device['screenTimeLimitId']);

    if (deviceId <= 0 || limitId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thiết bị chưa có giới hạn thời gian. '
                'Hãy nhờ phụ huynh thiết lập trước.',
          ),
        ),
      );
      return;
    }

    final refreshed = await _refreshChildToken();

    if (!refreshed) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xác thực thiết bị.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestExtraTimeScreen(
          deviceId: deviceId,
          screenTimeLimitId: limitId,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Widget _buildNotPaired() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.child_care,
              size: 90,
              color: Color(0xFF6254D9),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chào mừng đến KidGuard!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thiết bị chưa được liên kết '
                  'với phụ huynh.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _openPairing,
              icon: const Icon(Icons.qr_code),
              label: const Text(
                'Tạo mã QR ghép nối',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
      Map<String, dynamic> device,
      ) {
    final deviceName =
        device['deviceName']?.toString() ??
            'Thiết bị';

    final used =
    _toInt(device['usedMinutes']);

    final remaining =
    _toInt(device['remainingMinutes']);

    final limit =
    _toInt(device['effectiveLimitMinutes']);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smartphone),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    deviceName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Đã sử dụng: $used phút'),
            Text(
              limit > 0
                  ? 'Giới hạn: $limit phút'
                  : 'Chưa thiết lập giới hạn',
            ),
            if (limit > 0)
              Text('Còn lại: $remaining phút'),
            if (limit > 0) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (used / limit)
                    .clamp(0.0, 1.0)
                    .toDouble(),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _openLocation(device),
                  icon: const Icon(
                    Icons.location_on_outlined,
                  ),
                  label: const Text('Vị trí'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openUsage(device),
                  icon: const Icon(
                    Icons.bar_chart,
                  ),
                  label: const Text('Sử dụng'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _openRequestScreen(device),
                  icon: const Icon(
                    Icons.add_alarm,
                  ),
                  label: const Text(
                    'Xin thêm giờ',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final data = _dashboard ?? {};

    final childName =
        data['childName']?.toString() ??
            'Child';

    final rawDevices = data['devices'];

    final devices = rawDevices is List
        ? rawDevices
        .whereType<Map>()
        .map(
          (e) =>
      Map<String, dynamic>.from(e),
    )
        .toList()
        : <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Xin chào, $childName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thiết bị đã kết nối '
                'với phụ huynh.',
          ),
          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.location_on,
                color: Color(0xFF6254D9),
              ),
              title: const Text(
                'Vị trí thiết bị',
              ),
              subtitle: Text(
                _locationMessage ??
                    'Vị trí sẽ được cập nhật '
                        'khi mở ứng dụng.',
              ),
              trailing: IconButton(
                tooltip: 'Cập nhật vị trí',
                onPressed: _syncingLocation
                    ? null
                    : () => _syncLocation(),
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Thiết bị của tôi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Chưa có thiết bị '
                      'trong Dashboard.\n'
                      'Thiết bị hiện tại: '
                      '$_deviceName',
                ),
              ),
            )
          else
            ...devices.map(_buildDeviceCard),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Đã xảy ra lỗi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _initialize,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Thử lại',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KidGuard - Child',
        ),
        actions: [
          if (_paired && _error == null)
            IconButton(
              tooltip: 'Thông báo',
              onPressed: _openNotifications,
              icon: const Icon(
                Icons.notifications_outlined,
              ),
            ),
          if (_paired)
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _initialize,
              icon: const Icon(
                Icons.refresh,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : !_paired
          ? _buildNotPaired()
          : _error != null
          ? _buildError()
          : _buildDashboard(),
    );
  }
}
