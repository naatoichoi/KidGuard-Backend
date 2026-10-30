import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/api_service.dart';
import 'child_account_screen.dart';

class ParentPairingScreen extends StatefulWidget {
  // Giữ tham số này để không phải sửa ParentHomeScreen.
  final List<Map<String, dynamic>> children;

  const ParentPairingScreen({super.key, this.children = const []});

  @override
  State<ParentPairingScreen> createState() => _ParentPairingScreenState();
}

class _ParentPairingScreenState extends State<ParentPairingScreen> {
  final ApiService _api = ApiService();
  final MobileScannerController _scanner = MobileScannerController();

  final TextEditingController _codeController = TextEditingController();

  bool _processing = false;
  bool _scanned = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    _codeController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _resumeScanner() async {
    if (!mounted) return;

    setState(() {
      _scanned = false;
    });

    try {
      await _scanner.start();
    } catch (_) {
      // Camera có thể chưa sẵn sàng.
    }
  }

  Future<void> _showChildNameDialog(String qrData) async {
    if (_processing) return;

    final code = qrData.trim();

    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(code)) {
      setState(() {
        _error = 'Mã QR không hợp lệ.';
      });
      await _resumeScanner();
      return;
    }

    try {
      await _scanner.stop();
    } catch (_) {}

    if (!mounted) return;

    final account = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const ChildAccountScreen()),
    );
    if (!mounted) return;
    if (account == null) {
      await _resumeScanner();
      return;
    }
    await _confirmPairing(qrData: code, account: account);
  }

  Future<void> _confirmPairing({
    required String qrData,
    required Map<String, String> account,
  }) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      await _api.post('Pairing/confirm', body: {'qrData': qrData, ...account});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo tài khoản và liên kết thiết bị cho ${account['childName']}.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _processing = false;
      });

      await _resumeScanner();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned || _processing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.trim().isNotEmpty) {
        _scanned = true;
        _codeController.text = value.trim();

        _showChildNameDialog(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghép thiết bị Child')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Color(0xFF6254D9)),
          const SizedBox(height: 12),
          const Text(
            'Quét mã QR trên thiết bị Child',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sau khi quét, đặt tên đăng nhập và mật khẩu riêng cho con.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MobileScanner(controller: _scanner, onDetect: _onDetect),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Hoặc nhập mã ghép thủ công',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _codeController,
            enabled: !_processing,
            decoration: const InputDecoration(
              labelText: 'Mã ghép',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _processing
                ? null
                : () {
                    _showChildNameDialog(_codeController.text);
                  },
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(_processing ? 'Đang liên kết...' : 'Xác nhận liên kết'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
