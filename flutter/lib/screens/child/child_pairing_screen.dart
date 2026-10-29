
import 'dart:async';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api_service.dart';

class ChildPairingScreen extends StatefulWidget {
  const ChildPairingScreen({super.key});

  @override
  State<ChildPairingScreen> createState() =>
      _ChildPairingScreenState();
}

class _ChildPairingScreenState extends State<ChildPairingScreen> {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage =
  const FlutterSecureStorage();

  Timer? _pollTimer;
  Timer? _countdownTimer;

  String? _qrData;
  String? _secret;
  String? _error;

  bool _loading = true;
  bool _checking = false;
  bool _paired = false;

  int _remaining = 300;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _generation++;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  String _randomHex(int bytes) {
    final random = Random.secure();

    return List<int>.generate(
      bytes,
          (_) => random.nextInt(256),
    ).map(
          (b) => b.toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
  }

  Future<String> _deviceIdentifier() async {
    const key = 'kidguard_device_identifier';

    final existing = await _storage.read(key: key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final identifier = _randomHex(16);
    await _storage.write(key: key, value: identifier);
    return identifier;
  }

  Future<void> _initialize() async {
    try {
      final qr = await _storage.read(
        key: 'kidguard_pending_qr',
      );
      final secret = await _storage.read(
        key: 'kidguard_pending_secret',
      );
      final expiry = await _storage.read(
        key: 'kidguard_pending_expiry',
      );

      final expiresAt = DateTime.tryParse(expiry ?? '');

      if (qr != null &&
          secret != null &&
          expiresAt != null &&
          DateTime.now().isBefore(expiresAt)) {
        if (!mounted) return;

        setState(() {
          _qrData = qr;
          _secret = secret;
          _remaining =
              expiresAt.difference(DateTime.now()).inSeconds;
          _loading = false;
        });

        _startTimers();
        return;
      }
    } catch (_) {
      // Nếu không khôi phục được, tạo mã mới.
    }

    await _createPairingCode();
  }

  Future<void> _createPairingCode() async {
    _generation++;
    final generation = _generation;

    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _loading = true;
      _checking = false;
      _paired = false;
      _qrData = null;
      _secret = null;
      _error = null;
      _remaining = 300;
    });

    try {
      final android = await DeviceInfoPlugin().androidInfo;
      final identifier = await _deviceIdentifier();
      final secret = _randomHex(32);

      final response = await _api.post(
        'Pairing/create',
        authenticated: false,
        body: {
          'deviceIdentifier': identifier,
          'deviceName':
          '${android.brand} ${android.model}',
          'androidVersion': android.version.release,
          'deviceSecret': secret,
        },
      );

      final data = Map<String, dynamic>.from(
        response as Map,
      );

      final qr = data['qrData']?.toString() ?? '';
      if (!RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(qr)) {
        throw Exception('Mã QR không hợp lệ.');
      }

      final seconds =
          (data['expiresInSeconds'] as num?)?.toInt() ??
              300;

      await _storage.write(
        key: 'kidguard_pending_qr',
        value: qr,
      );
      await _storage.write(
        key: 'kidguard_pending_secret',
        value: secret,
      );
      await _storage.write(
        key: 'kidguard_pending_expiry',
        value: DateTime.now()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
      );

      if (!mounted || generation != _generation) return;

      setState(() {
        _qrData = qr;
        _secret = secret;
        _remaining = seconds;
        _loading = false;
      });

      _startTimers();
    } catch (e) {
      if (!mounted || generation != _generation) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted || _paired) {
          timer.cancel();
          return;
        }

        if (_remaining <= 1) {
          timer.cancel();
          _pollTimer?.cancel();

          setState(() => _remaining = 0);
          return;
        }

        setState(() => _remaining--);
      },
    );

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _checkStatus(),
    );

    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_checking ||
        _paired ||
        _qrData == null ||
        _secret == null ||
        _remaining <= 0) {
      return;
    }

    _checking = true;
    final generation = _generation;

    try {
      final response = await _api.post(
        'Pairing/status',
        authenticated: false,
        body: {
          'qrData': _qrData,
          'deviceSecret': _secret,
        },
      );

      final data = Map<String, dynamic>.from(
        response as Map,
      );

      if (!mounted || generation != _generation) return;

      final status =
      data['status']?.toString().toUpperCase();

      if (status == 'USED') {
        final token = data['token']?.toString();
        final deviceId = data['deviceId']?.toString();
        final childId = data['childId']?.toString();

        if (token == null ||
            token.isEmpty ||
            deviceId == null ||
            childId == null) {
          throw Exception('Thiếu thông tin xác thực.');
        }

        await _storage.write(
          key: 'kidguard_jwt',
          value: token,
        );
        await _storage.write(
          key: 'kidguard_device_id',
          value: deviceId,
        );
        await _storage.write(
          key: 'kidguard_child_id',
          value: childId,
        );
        await _storage.write(
          key: 'kidguard_device_name',
          value: data['deviceName']?.toString() ??
              'Thiết bị',
        );

        // Secret riêng được giữ lại để cấp JWT mới.
        await _storage.write(
          key: 'kidguard_device_secret',
          value: _secret!,
        );

        await _storage.delete(
          key: 'kidguard_pending_qr',
        );
        await _storage.delete(
          key: 'kidguard_pending_secret',
        );
        await _storage.delete(
          key: 'kidguard_pending_expiry',
        );

        _pollTimer?.cancel();
        _countdownTimer?.cancel();

        if (!mounted || generation != _generation) return;

        setState(() => _paired = true);

        Navigator.of(context).pop(true);
      } else if (status == 'EXPIRED' ||
          status == 'REVOKED') {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();

        setState(() {
          _remaining = 0;
          _error = 'Mã QR không còn hiệu lực.';
        });
      } else if (_error != null) {
        setState(() => _error = null);
      }
    } catch (e) {
      if (!mounted || generation != _generation) return;

      setState(() => _error = e.toString());
    } finally {
      _checking = false;
    }
  }

  String _formatTime() {
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghép thiết bị Child'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.child_care,
                size: 70,
                color: Color(0xFF6254D9),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kết nối với phụ huynh',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nhờ phụ huynh quét mã QR này.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              if (_loading)
                const CircularProgressIndicator()
              else if (_qrData != null &&
                  _remaining > 0 &&
                  !_paired)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: QrImageView(
                    data: _qrData!,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.qr_code_2,
                  size: 100,
                  color: Colors.grey,
                ),

              const SizedBox(height: 18),

              if (_remaining > 0 &&
                  _qrData != null &&
                  !_paired) ...[
                Text('Mã hết hạn sau ${_formatTime()}'),
                const SizedBox(height: 8),
                const Text(
                  'Đang chờ phụ huynh xác nhận...',
                  textAlign: TextAlign.center,
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],

              const SizedBox(height: 24),

              if (!_loading && !_paired)
                FilledButton.icon(
                  onPressed: _createPairingCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tạo mã QR mới'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
