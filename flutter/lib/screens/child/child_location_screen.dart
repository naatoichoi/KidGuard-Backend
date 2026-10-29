
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';

class ChildLocationScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const ChildLocationScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<ChildLocationScreen> createState() =>
      _ChildLocationScreenState();
}

class _ChildLocationScreenState
    extends State<ChildLocationScreen> {
  final ApiService _api = ApiService();

  Position? _position;
  DateTime? _lastSyncedAt;
  bool _loading = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'GPS đang tắt. Hãy bật dịch vụ vị trí trên điện thoại.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Bạn chưa cấp quyền truy cập vị trí.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Quyền vị trí đã bị từ chối vĩnh viễn. '
            'Hãy mở Cài đặt để cấp quyền.',
      );
    }

    return true;
  }

  Future<void> _syncLocation() async {
    if (_loading) return;

    if (widget.deviceId <= 0) {
      setState(() {
        _error = 'ID thiết bị không hợp lệ.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await _ensureLocationPermission();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      final recordedAt = position.timestamp;

      final response = await _api.post(
        'Locations/sync',
        body: {
          'deviceId': widget.deviceId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'recordedAt': recordedAt.toUtc().toIso8601String(),
          'source': 'FUSED',
        },
      );

      if (!mounted) return;

      final data = Map<String, dynamic>.from(
        response as Map,
      );

      setState(() {
        _position = position;
        _lastSyncedAt = DateTime.now();
        _message = data['message']?.toString() ??
            'Đồng bộ vị trí thành công.';
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(local.hour)}:${two(local.minute)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đồng bộ vị trí'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.location_on,
            size: 72,
            color: Color(0xFF6254D9),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chia sẻ vị trí với phụ huynh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vị trí được gửi lên KidGuard khi bạn '
                'nhấn nút đồng bộ bên dưới.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _infoRow(
                    'Thiết bị',
                    widget.deviceName,
                  ),
                  _infoRow(
                    'Device ID',
                    '${widget.deviceId}',
                  ),
                  if (_position != null) ...[
                    const Divider(height: 24),
                    _infoRow(
                      'Vĩ độ',
                      _position!.latitude.toStringAsFixed(6),
                    ),
                    _infoRow(
                      'Kinh độ',
                      _position!.longitude.toStringAsFixed(6),
                    ),
                    _infoRow(
                      'Độ chính xác',
                      '${_position!.accuracy.toStringAsFixed(1)} m',
                    ),
                  ],
                  if (_lastSyncedAt != null)
                    _infoRow(
                      'Đồng bộ lúc',
                      _formatDate(_lastSyncedAt!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_message != null)
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _syncLocation,
            icon: _loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.my_location),
            label: Text(
              _loading
                  ? 'Đang lấy GPS và đồng bộ...'
                  : 'Lấy GPS và đồng bộ ngay',
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: Geolocator.openLocationSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Mở cài đặt vị trí'),
          ),
        ],
      ),
    );
  }
}
