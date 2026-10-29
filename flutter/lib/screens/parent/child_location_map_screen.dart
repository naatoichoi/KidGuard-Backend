
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';

class ChildLocationMapScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ChildLocationMapScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildLocationMapScreen> createState() =>
      _ChildLocationMapScreenState();
}

class _ChildLocationMapScreenState
    extends State<ChildLocationMapScreen> {
  final ApiService _api = ApiService();

  GoogleMapController? _mapController;

  Map<String, dynamic>? _latestLocation;
  List<Map<String, dynamic>> _history = [];

  DateTime? _selectedDate;
  bool _loading = true;
  bool _historyLoading = false;
  String? _error;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadLatestLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _api.dispose();
    super.dispose();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (date == null) return 'Không rõ';

    final local = date.toLocal();

    String two(int number) =>
        number.toString().padLeft(2, '0');

    return '${two(local.hour)}:${two(local.minute)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  String _dateQuery(DateTime date) {
    String two(int number) =>
        number.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  LatLng? _coordinates(Map<String, dynamic>? location) {
    if (location == null) return null;

    final latitude = _toDouble(location['latitude']);
    final longitude = _toDouble(location['longitude']);

    if (latitude == null || longitude == null) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  Future<void> _loadLatestLocation() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.get(
        'Locations/child/${widget.childId}/latest',
      );

      final data = Map<String, dynamic>.from(
        response as Map,
      );

      final location = Map<String, dynamic>.from(
        data['location'] as Map,
      );

      if (!mounted) return;

      setState(() {
        _latestLocation = location;
        _loading = false;
      });

      final point = _coordinates(location);

      if (point != null) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(point, 16),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _historyLoading = true;
      _historyError = null;
    });

    try {
      var path =
          'Locations/child/${widget.childId}/history'
          '?page=1&pageSize=50';

      if (_selectedDate != null) {
        path += '&date=${_dateQuery(_selectedDate!)}';
      }

      final response = await _api.get(path);

      final data = Map<String, dynamic>.from(
        response as Map,
      );

      final raw = data['locations'];

      if (!mounted) return;

      setState(() {
        _history = raw is List
            ? raw
            .whereType<Map>()
            .map(
              (item) =>
          Map<String, dynamic>.from(item),
        )
            .toList()
            : [];
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _historyError = e.toString();
        _historyLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadHistory();
  }

  Widget _buildMap() {
    final point = _coordinates(_latestLocation);

    if (point == null) {
      return const Card(
        child: SizedBox(
          height: 250,
          child: Center(
            child: Text(
              'Chưa có tọa độ để hiển thị bản đồ.',
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: point,
            zoom: 16,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('child_latest'),
              position: point,
              infoWindow: InfoWindow(
                title: widget.childName,
                snippet: _latestLocation?['deviceName']
                    ?.toString(),
              ),
            ),
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
          },
        ),
      ),
    );
  }

  Widget _buildLatestDetails() {
    final location = _latestLocation;

    if (location == null) {
      return const SizedBox.shrink();
    }

    final accuracy = _toDouble(
      location['accuracyMeters'],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Vị trí gần nhất',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thiết bị: '
                  '${location['deviceName'] ?? 'Không rõ'}',
            ),
            const SizedBox(height: 8),
            Text(
              'Ghi nhận: '
                  '${_formatDate(location['recordedAt'])}',
            ),
            const SizedBox(height: 8),
            Text(
              'Độ chính xác: '
                  '${accuracy == null ? 'Không rõ' : '${accuracy.toStringAsFixed(1)} m'}',
            ),
            const SizedBox(height: 8),
            Text(
              'Nguồn: ${location['source'] ?? 'Không rõ'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch sử vị trí',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _selectedDate == null
                    ? 'Chọn ngày'
                    : _dateQuery(_selectedDate!),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
                _loadHistory();
              },
              child: const Text('Tất cả'),
            ),
            IconButton(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_historyLoading)
          const Center(
            child: CircularProgressIndicator(),
          )
        else if (_historyError != null)
          Text(
            _historyError!,
            style: const TextStyle(color: Colors.red),
          )
        else if (_history.isEmpty)
            const Text(
              'Chưa có lịch sử vị trí.',
              style: TextStyle(
                color: Colors.black54,
              ),
            )
          else
            ..._history.map((location) {
              final point = _coordinates(location);

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF6254D9),
                  ),
                  title: Text(
                    _formatDate(location['recordedAt']),
                  ),
                  subtitle: Text(
                    location['deviceName']?.toString() ??
                        'Thiết bị',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: point == null
                      ? null
                      : () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        point,
                        16,
                      ),
                    );
                  },
                ),
              );
            }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vị trí · ${widget.childName}'),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadLatestLocation();
              await _loadHistory();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildMap(),
          const SizedBox(height: 16),
          _buildLatestDetails(),
          const SizedBox(height: 28),
          _buildHistory(),
        ],
      ),
    );
  }
}
