import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/location_sharing_service.dart';
import '../../widgets/location_map_card.dart';

class ChildLocationMapScreen extends StatefulWidget {
  const ChildLocationMapScreen({
    super.key,
    required this.childId,
    required this.childName,
  });
  final int childId;
  final String childName;
  @override
  State<ChildLocationMapScreen> createState() => _ChildLocationMapScreenState();
}

class _ChildLocationMapScreenState extends State<ChildLocationMapScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _latest;
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _history = [];
  String? _address;
  String? _error;
  String? _historyError;
  bool _loading = true;
  bool _addressLoading = false;
  DateTime? _date;
  int _selection = 0;
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

  String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _time(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return 'Không rõ thời điểm';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await _api.get('Locations/child/${widget.childId}/latest') as Map;
      if (!mounted) return;
      _latest = Map<String, dynamic>.from(result['location'] as Map);
      await _select(_latest!);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _loadHistory();
  }

  Future<void> _select(Map<String, dynamic> location) async {
    final latitude = (location['latitude'] as num?)?.toDouble();
    final longitude = (location['longitude'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }
    final selection = ++_selection;
    setState(() {
      _selected = location;
      _address = location['address']?.toString();
      _addressLoading = _address == null;
    });
    if (_address != null) return;
    final address = await LocationSharingService.addressFor(
      latitude,
      longitude,
    );
    if (mounted && selection == _selection) {
      setState(() {
        _address = address;
        _addressLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    try {
      final response = await _api.get(
        'Locations/child/${widget.childId}/history',
        query: {
          'page': '1',
          'pageSize': '50',
          if (_date != null) 'date': _day(_date!),
        },
      ) as Map;
      if (mounted) {
        setState(() {
          _history = (response['locations'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _historyError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _historyError = '$error');
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    setState(() => _date = date);
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Text('Vị trí · ${widget.childName}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && selected == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 16),
                    LocationMapCard(
                      latitude: (selected['latitude'] as num).toDouble(),
                      longitude: (selected['longitude'] as num).toDouble(),
                      accuracy: (selected['accuracyMeters'] as num?)
                          ?.toDouble(),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected['id'] == _latest?['id']
                                  ? 'Vị trí gửi gần nhất'
                                  : 'Đang xem một vị trí trong lịch sử',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _addressLoading
                                  ? 'Đang tra địa chỉ…'
                                  : _address ?? 'Chưa lấy được địa chỉ',
                            ),
                            const SizedBox(height: 12),
                            Text('Ghi nhận: ${_time(selected['recordedAt'])}'),
                            Text(
                              'Thiết bị: ${selected['deviceName'] ?? 'Điện thoại của con'}',
                            ),
                            if (selected['accuracyMeters'] is num)
                              Text(
                                'Sai số khoảng ${(selected['accuracyMeters'] as num).toStringAsFixed(0)} m',
                              ),
                            Text(
                              '${selected['latitude']}, ${selected['longitude']}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa nhận được vị trí của con.',
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_latest != null)
                    TextButton(
                      onPressed: () => _select(_latest!),
                      child: const Text('Xem vị trí gửi mới nhất'),
                    ),
                  const Text(
                    'Lịch sử gửi vị trí',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(_date == null ? 'Chọn ngày' : _day(_date!)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _date = null);
                          _loadHistory();
                        },
                        child: const Text('Tất cả'),
                      ),
                    ],
                  ),
                  if (_historyError != null)
                    Text(
                      _historyError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ..._history.map(
                    (location) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(_time(location['recordedAt'])),
                        subtitle: Text(
                          location['deviceName']?.toString() ?? 'Thiết bị',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _select(location),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
