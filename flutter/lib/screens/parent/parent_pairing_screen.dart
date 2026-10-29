
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/api_service.dart';

class ParentPairingScreen extends StatefulWidget {
  // Giữ tham số này để không phải sửa ParentHomeScreen.
  final List<Map<String, dynamic>> children;

  const ParentPairingScreen({
    super.key,
    this.children = const [],
  });

  @override
  State<ParentPairingScreen> createState() =>
      _ParentPairingScreenState();
}

class _ParentPairingScreenState extends State<ParentPairingScreen> {
  final ApiService _api = ApiService();
  final MobileScannerController _scanner =
  MobileScannerController();

  final TextEditingController _codeController =
  TextEditingController();

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

    final nameController = TextEditingController();
    String? validationError;

    final childName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm trẻ em mới'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nhập tên trẻ em để liên kết thiết bị.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 100,
                    textCapitalization:
                    TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Tên trẻ em',
                      hintText: 'Ví dụ: Bé An',
                      border: const OutlineInputBorder(),
                      errorText: validationError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      setDialogState(() {
                        validationError =
                        'Vui lòng nhập tên trẻ em.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(name);
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (!mounted) return;

    if (childName == null) {
      await _resumeScanner();
      return;
    }

    await _confirmPairing(
      qrData: code,
      childName: childName,
    );
  }

  Future<void> _confirmPairing({
    required String qrData,
    required String childName,
  }) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      await _api.post(
        'Pairing/confirm',
        body: {
          'qrData': qrData,
          'childName': childName,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã liên kết thiết bị cho $childName.',
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
      appBar: AppBar(
        title: const Text('Ghép thiết bị Child'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: Color(0xFF6254D9),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quét mã QR trên thiết bị Child',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sau khi quét, nhập tên trẻ em để hoàn tất liên kết.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MobileScanner(
                controller: _scanner,
                onDetect: _onDetect,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Hoặc nhập mã ghép thủ công',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
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
              _showChildNameDialog(
                _codeController.text,
              );
            },
            icon: _processing
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.link),
            label: Text(
              _processing
                  ? 'Đang liên kết...'
                  : 'Xác nhận liên kết',
            ),
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
