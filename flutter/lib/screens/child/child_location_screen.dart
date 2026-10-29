import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_sharing_service.dart';
import '../../widgets/location_map_card.dart';

class ChildLocationScreen extends StatefulWidget {
  const ChildLocationScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });
  final int deviceId;
  final String deviceName;
  @override
  State<ChildLocationScreen> createState() => _ChildLocationScreenState();
}

class _ChildLocationScreenState extends State<ChildLocationScreen> {
  final _sharing = LocationSharingService();
  SharedLocation? _location;
  bool _sending = false;
  bool _sent = true;
  bool _auto = false;
  String? _error;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final location = await _sharing.lastShared(widget.deviceId);
    final auto = await _sharing.autoEnabled(widget.deviceId);
    if (mounted) {
      setState(() {
        _location = location;
        _auto = auto;
      });
    }
  }

  @override
  void dispose() {
    _sharing.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _message = null;
    });
    try {
      final location = await _sharing.share(
        widget.deviceId,
        onLocated: (location) {
          if (mounted) {
            setState(() {
              _location = location;
              _sent = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _location = location;
          _sent = true;
          _message = 'Đã gửi vị trí cho phụ huynh.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(DateTime value) {
    final date = value.toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    return Scaffold(
      appBar: AppBar(title: const Text('Chia sẻ vị trí')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.deviceName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Đang gửi…' : 'Gửi vị trí của con'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          if (location != null) ...[
            Text(
              _sent ? 'Vị trí đã gửi gần nhất' : 'Vị trí chưa gửi',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LocationMapCard(
              latitude: location.latitude,
              longitude: location.longitude,
              accuracy: location.accuracy,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Địa chỉ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(location.address ?? 'Chưa lấy được địa chỉ'),
                    const SizedBox(height: 12),
                    Text('Ghi nhận: ${_time(location.recordedAt)}'),
                    if (location.accuracy != null)
                      Text(
                        'Sai số: ${location.accuracy!.toStringAsFixed(0)} m',
                      ),
                    Text(
                      '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tự gửi khi mở ứng dụng'),
            value: _auto,
            onChanged: _sending
                ? null
                : (value) async {
                    await _sharing.setAutoEnabled(widget.deviceId, value);
                    if (mounted) setState(() => _auto = value);
                  },
          ),
          TextButton.icon(
            onPressed: Geolocator.openLocationSettings,
            icon: const Icon(Icons.gps_fixed),
            label: const Text('Cài đặt GPS'),
          ),
          TextButton.icon(
            onPressed: Geolocator.openAppSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Quyền vị trí'),
          ),
        ],
      ),
    );
  }
}
