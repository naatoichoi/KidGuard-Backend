import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'app_picker_screen.dart';

class ScreenTimeLimitsScreen extends StatefulWidget {
  const ScreenTimeLimitsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.childId,
    this.initialPackageName,
    this.api,
  });
  final int deviceId;
  final String deviceName;
  final int? childId;
  final String? initialPackageName;
  final ApiService? api;
  @override
  State<ScreenTimeLimitsScreen> createState() => _ScreenTimeLimitsScreenState();
}

class _ScreenTimeLimitsScreenState extends State<ScreenTimeLimitsScreen> {
  late final _api = widget.api ?? ApiService();
  List<Map<String, dynamic>> _limits = [];
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  bool _deleting = false;
  bool _openedInitial = false;
  String? _error;
  String? _appsError;
  String? _lastSync;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  Map<String, dynamic>? _app(String? package) =>
      _apps.where((app) => app['packageName'] == package).firstOrNull;
  String _appName(String? package) =>
      _app(package)?['appName']?.toString() ?? 'Ứng dụng đã đặt giới hạn';
  String _used(String? package) {
    if (_app(package) == null) return 'chưa có số liệu';
    final seconds = _number(_app(package)?['durationSeconds']);
    return '${seconds ~/ 60} phút ${seconds % 60} giây';
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _appsError = null;
    });
    try {
      final limits =
          await _api.get('ScreenTimeLimits/device/${widget.deviceId}') as List;
      List<Map<String, dynamic>> apps = [];
      String? appsError;
      String? lastSync;
      try {
        final catalog = await _api.get('DeviceApps/${widget.deviceId}') as Map;
        apps = (catalog['apps'] as List)
            .whereType<Map>()
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
        lastSync = catalog['lastSyncAt']?.toString();
      } catch (_) {
        appsError = 'Chưa tải được danh sách app. Kiểm tra mạng và chạy lại backend bản mới trong Visual Studio.';
      }
      if (!mounted) return;
      setState(() {
        _limits = limits
            .whereType<Map>()
            .map((l) => Map<String, dynamic>.from(l))
            .toList();
        _apps = apps;
        _lastSync = lastSync;
        _appsError = appsError;
        _loading = false;
      });
      if (!_openedInitial && widget.initialPackageName != null) {
        _openedInitial = true;
        final existing = _limits
            .where(
              (l) =>
                  l['limitType'] == 'APP' &&
                  l['packageName'] == widget.initialPackageName,
            )
            .firstOrNull;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showLimitDialog(
              existing: existing,
              package: widget.initialPackageName,
            );
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _showLimitDialog({
    Map<String, dynamic>? existing,
    String? package,
  }) async {
    final editing = existing != null;
    String type =
        existing?['limitType']?.toString() ??
        (package == null ? 'TOTAL' : 'APP');
    String? selectedPackage =
        existing?['packageName']?.toString() ??
        (_app(package) == null ? null : package);
    final minutes = TextEditingController(
      text: existing?['dailyLimitMinutes']?.toString() ?? '60',
    );
    bool enabled = existing?['isEnabled'] != false;
    bool saving = false;
    String? error;
    final form = GlobalKey<FormState>();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text(editing ? 'Sửa giới hạn' : 'Thêm giới hạn'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Giới hạn cho',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'TOTAL',
                            child: Text('Tổng thời gian điện thoại'),
                          ),
                          DropdownMenuItem(
                            value: 'APP',
                            child: Text('Một ứng dụng cụ thể'),
                          ),
                        ],
                        onChanged: editing || saving
                            ? null
                            : (value) {
                                if (value != null) update(() => type = value);
                              },
                      ),
                      if (type == 'APP') ...[
                        const SizedBox(height: 16),
                        FormField<String>(
                          initialValue: selectedPackage,
                          validator: (_) => selectedPackage == null
                              ? 'Hãy chọn ứng dụng từ máy trẻ'
                              : null,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: editing || saving || _apps.isEmpty
                                    ? null
                                    : () async {
                                        final result =
                                            await Navigator.push<String>(
                                              dialogContext,
                                              MaterialPageRoute(
                                                builder: (_) => AppPickerScreen(
                                                  apps: _apps,
                                                  selectedPackage:
                                                      selectedPackage,
                                                ),
                                              ),
                                            );
                                        if (result != null &&
                                            dialogContext.mounted) {
                                          update(() {
                                            selectedPackage = result;
                                            field.didChange(result);
                                          });
                                        }
                                      },
                                icon: const Icon(Icons.apps),
                                label: Text(
                                  selectedPackage == null
                                      ? 'Chọn ứng dụng'
                                      : _appName(selectedPackage),
                                ),
                              ),
                              if (selectedPackage != null)
                                Text(
                                  'Đã dùng hôm nay: ${_used(selectedPackage)}',
                                ),
                              if (_apps.isEmpty)
                                const Text(
                                  'Trên máy trẻ, mở Thời gian sử dụng và bấm Đồng bộ danh sách & thời gian, rồi tải lại màn hình này.',
                                ),
                              if (field.hasError)
                                Text(
                                  field.errorText!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: minutes,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cho phép mỗi ngày',
                          suffixText: 'phút',
                        ),
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          return number == null || number < 1 || number > 1440
                              ? 'Nhập từ 1 đến 1440 phút'
                              : null;
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bật giới hạn'),
                        value: enabled,
                        onChanged: saving
                            ? null
                            : (value) => update(() => enabled = value),
                      ),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final body = {
                            'deviceId': widget.deviceId,
                            'limitType': type,
                            'packageName': type == 'APP'
                                ? selectedPackage
                                : null,
                            'dailyLimitMinutes': int.parse(minutes.text.trim()),
                            'isEnabled': enabled,
                          };
                          if (editing) {
                            await _api.put(
                              'ScreenTimeLimits/${existing['id']}',
                              body: body,
                            );
                          } else {
                            await _api.post('ScreenTimeLimits', body: body);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) await _load();
                        } catch (failure) {
                          if (dialogContext.mounted) {
                            update(() => error = '$failure');
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            update(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Đang lưu…' : 'Lưu'),
              ),
            ],
          ),
        ),
      );
    } finally {
      minutes.dispose();
    }
  }

  Future<void> _delete(Map<String, dynamic> limit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa giới hạn?'),
        content: const Text(
          'Giới hạn chưa có lịch sử xin thêm giờ sẽ được xóa. Nếu đã có lịch sử, hãy sửa và tắt để giữ dữ liệu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _deleting) return;
    setState(() => _deleting = true);
    try {
      await _api.delete('ScreenTimeLimits/${limit['id']}');
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Giới hạn thời gian'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading || _deleting ? null : () => _showLimitDialog(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm giới hạn'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  widget.deviceName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_appsError != null)
                  Text(
                    _appsError!,
                    style: const TextStyle(color: Colors.orange),
                  ),
                const SizedBox(height: 12),
                Text('${_apps.length} ứng dụng trong lần đồng bộ gần nhất'),
                if (_lastSync != null)
                  Text(
                    'Đồng bộ: ${DateTime.tryParse(_lastSync!)?.toLocal().toString().split('.').first ?? _lastSync}',
                  ),
                const SizedBox(height: 20),
                if (_limits.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa có giới hạn. Bấm Thêm giới hạn để thiết lập.',
                      ),
                    ),
                  ),
                ..._limits.map(
                  (limit) => Card(
                    child: ListTile(
                      leading: Icon(
                        limit['limitType'] == 'TOTAL'
                            ? Icons.phonelink_lock
                            : Icons.apps,
                      ),
                      title: Text(
                        limit['limitType'] == 'TOTAL'
                            ? 'Tổng thời gian điện thoại'
                            : _appName(limit['packageName']?.toString()),
                      ),
                      subtitle: Text(
                        '${limit['dailyLimitMinutes']} phút/ngày · ${limit['isEnabled'] == true ? 'Đang bật' : 'Đã tắt'}${limit['limitType'] == 'APP' ? '\nĐã dùng hôm nay: ${_used(limit['packageName']?.toString())}' : ''}',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Sửa giới hạn',
                            onPressed: _deleting
                                ? null
                                : () => _showLimitDialog(existing: limit),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Xóa giới hạn',
                            onPressed: _deleting ? null : () => _delete(limit),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
