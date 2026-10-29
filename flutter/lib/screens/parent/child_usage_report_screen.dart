
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ChildUsageReportScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildUsageReportScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildUsageReportScreen> createState() =>
      _ChildUsageReportScreenState();
}

class _ChildUsageReportScreenState
    extends State<ChildUsageReportScreen> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;
  DateTime _date = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  String _dateString(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.get(
        'ScreenTime/child/${widget.childId}'
            '?date=${_dateString(_date)}',
      );

      if (!mounted) return;

      setState(() {
        _report = Map<String, dynamic>.from(response as Map);
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

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) return;

    _date = selected;
    await _load();
  }

  Widget _deviceCard(Map<String, dynamic> device) {
    final rawApps = device['apps'];
    final apps = rawApps is List ? rawApps : [];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device['deviceName']?.toString() ?? 'Thiết bị',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tổng: ${_number(device['totalMinutes']).toStringAsFixed(1)} phút',
            ),
            const Divider(height: 24),
            if (apps.isEmpty)
              const Text('Chưa có dữ liệu ứng dụng.')
            else
              ...apps.whereType<Map>().map((app) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apps),
                  title: Text(
                    app['appName']?.toString() ??
                        app['packageName']?.toString() ??
                        'Ứng dụng',
                  ),
                  subtitle: Text(
                    app['packageName']?.toString() ?? '',
                  ),
                  trailing: Text(
                    '${_number(app['durationMinutes']).toStringAsFixed(1)} phút',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawDevices = _report?['devices'];
    final devices = rawDevices is List ? rawDevices : [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Sử dụng · ${widget.childName}'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_dateString(_date)),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFEAE7FF),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Tổng thời gian sử dụng'),
                  const SizedBox(height: 8),
                  Text(
                    '${_number(_report?['totalMinutes']).toStringAsFixed(1)} phút',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (devices.isEmpty)
            const Text('Chưa có thiết bị hoặc dữ liệu.')
          else
            ...devices.whereType<Map>().map(
                  (device) => _deviceCard(
                Map<String, dynamic>.from(device),
              ),
            ),
        ],
      ),
    );
  }
}
