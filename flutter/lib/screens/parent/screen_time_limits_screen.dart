
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class ScreenTimeLimitsScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const ScreenTimeLimitsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<ScreenTimeLimitsScreen> createState() =>
      _ScreenTimeLimitsScreenState();
}

class _ScreenTimeLimitsScreenState
    extends State<ScreenTimeLimitsScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _limits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLimits();
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

  Future<void> _loadLimits() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.get(
        'ScreenTimeLimits/device/${widget.deviceId}',
      );

      if (!mounted) return;

      setState(() {
        _limits = (result as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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

  Future<void> _showLimitDialog({
    Map<String, dynamic>? existing,
  }) async {
    final bool isEditing = existing != null;

    String limitType =
        existing?['limitType']?.toString().toUpperCase() ?? 'TOTAL';

    final packageController = TextEditingController(
      text: existing?['packageName']?.toString() ?? '',
    );

    final minutesController = TextEditingController(
      text: existing?['dailyLimitMinutes']?.toString() ?? '120',
    );

    bool isEnabled = existing?['isEnabled'] == null
        ? true
        : existing!['isEnabled'] == true;

    bool saving = false;
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  isEditing ? 'Sửa giới hạn' : 'Thêm giới hạn',
                ),
                content: SizedBox(
                  width: 380,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: limitType,
                            decoration: const InputDecoration(
                              labelText: 'Loại giới hạn',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'TOTAL',
                                child: Text('Tổng thời gian'),
                              ),
                              DropdownMenuItem(
                                value: 'APP',
                                child: Text('Theo ứng dụng'),
                              ),
                            ],
                            onChanged: isEditing || saving
                                ? null
                                : (value) {
                              if (value != null) {
                                setDialogState(() {
                                  limitType = value;
                                });
                              }
                            },
                          ),
                          if (limitType == 'APP') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: packageController,
                              readOnly: isEditing || saving,
                              decoration: const InputDecoration(
                                labelText: 'Package Name',
                                hintText: 'com.google.android.youtube',
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Nhập Package Name';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: minutesController,
                            enabled: !saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Giới hạn (phút/ngày)',
                              suffixText: 'phút',
                            ),
                            validator: (value) {
                              final minutes =
                              int.tryParse(value?.trim() ?? '');

                              if (minutes == null || minutes < 1) {
                                return 'Nhập số phút lớn hơn 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bật giới hạn'),
                            value: isEnabled,
                            onChanged: saving
                                ? null
                                : (value) {
                              setDialogState(() {
                                isEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      setDialogState(() {
                        saving = true;
                      });

                      try {
                        await _api.post(
                          'ScreenTimeLimits',
                          body: {
                            'deviceId': widget.deviceId,
                            'limitType': limitType,
                            'packageName': limitType == 'APP'
                                ? packageController.text.trim()
                                : null,
                            'dailyLimitMinutes': int.parse(
                              minutesController.text.trim(),
                            ),
                            'isEnabled': isEnabled,
                          },
                        );

                        if (!mounted) return;

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Lưu giới hạn thành công.',
                            ),
                          ),
                        );

                        await _loadLimits();
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                          });
                        }
                      }
                    },
                    child: saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Lưu'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      packageController.dispose();
      minutesController.dispose();
    }
  }

  Widget _limitCard(Map<String, dynamic> limit) {
    final type = limit['limitType']?.toString() ?? 'TOTAL';
    final isEnabled = limit['isEnabled'] == true;
    final minutes = _toInt(limit['dailyLimitMinutes']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAE7FF),
          child: Icon(
            type == 'TOTAL' ? Icons.timer : Icons.apps,
            color: const Color(0xFF6254D9),
          ),
        ),
        title: Text(
          type == 'TOTAL'
              ? 'Tổng thời gian sử dụng'
              : limit['packageName']?.toString() ?? 'Ứng dụng',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$minutes phút/ngày\n'
                '${isEnabled ? 'Đang bật' : 'Đã tắt'}',
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _showLimitDialog(existing: limit),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giới hạn thời gian'),
        actions: [
          IconButton(
            onPressed: _loadLimits,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLimitDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm giới hạn'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadLimits,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadLimits,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
          children: [
            Text(
              widget.deviceName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thiết lập thời gian sử dụng mỗi ngày '
                  'cho thiết bị của con.',
            ),
            const SizedBox(height: 24),
            if (_limits.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa có giới hạn nào. '
                        'Nhấn "Thêm giới hạn" để tạo mới.',
                  ),
                ),
              )
            else
              ..._limits.map(_limitCard),
          ],
        ),
      ),
    );
  }
}
