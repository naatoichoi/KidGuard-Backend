
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class RequestExtraTimeScreen extends StatefulWidget {
  final int deviceId;
  final int screenTimeLimitId;

  const RequestExtraTimeScreen({
    super.key,
    required this.deviceId,
    required this.screenTimeLimitId,
  });

  @override
  State<RequestExtraTimeScreen> createState() =>
      _RequestExtraTimeScreenState();
}

class _RequestExtraTimeScreenState
    extends State<RequestExtraTimeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _reasonController =
  TextEditingController();

  int _requestedMinutes = 30;
  bool _sending = false;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _api.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _toList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (response is Map) {
      for (final key in ['requests', 'items', 'data']) {
        if (response[key] is List) {
          return _toList(response[key]);
        }
      }
    }

    return [];
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.get('TimeRequests/my');

      if (!mounted) return;

      setState(() {
        _requests = _toList(response);
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

  Future<void> _sendRequest() async {
    if (_sending) return;

    if (widget.deviceId <= 0 || widget.screenTimeLimitId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thiết bị chưa có giới hạn thời gian hợp lệ.',
          ),
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập lý do xin thêm thời gian.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _api.post(
        'TimeRequests',
        body: {
          'deviceId': widget.deviceId,
          'screenTimeLimitId': widget.screenTimeLimitId,
          'requestedMinutes': _requestedMinutes,
          'reason': reason,
        },
      );

      if (!mounted) return;

      _reasonController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi yêu cầu. Hãy chờ phụ huynh phê duyệt.',
          ),
        ),
      );

      await _loadRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _statusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Đang chờ duyệt';
      case 'APPROVED':
        return 'Đã phê duyệt';
      case 'REJECTED':
        return 'Đã từ chối';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final minutes = _toInt(request['requestedMinutes']);
    final status =
        request['status']?.toString() ?? 'PENDING';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAE7FF),
          child: Icon(
            status.toUpperCase() == 'APPROVED'
                ? Icons.check_circle_outline
                : Icons.schedule,
            color: _statusColor(status),
          ),
        ),
        title: Text(
          'Xin thêm $minutes phút',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${request['reason'] ?? ''}\n'
              '${_statusText(status)}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 64,
            color: Color(0xFF6254D9),
          ),
          const SizedBox(height: 16),
          const Text(
            'Xin thêm thời gian',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gửi yêu cầu để phụ huynh xem xét '
                'cho phép sử dụng thiết bị lâu hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 28),
          const Text(
            'Muốn thêm bao nhiêu phút?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [15, 30, 45, 60].map((minutes) {
              return ChoiceChip(
                label: Text('$minutes phút'),
                selected: _requestedMinutes == minutes,
                onSelected: _sending
                    ? null
                    : (_) {
                  setState(() {
                    _requestedMinutes = minutes;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _reasonController,
            enabled: !_sending,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Lý do xin thêm thời gian',
              hintText: 'Ví dụ: Con muốn học thêm 30 phút.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _sendRequest,
            icon: _sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.send),
            label: Text(
              _sending ? 'Đang gửi...' : 'Gửi yêu cầu',
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Yêu cầu đã gửi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_requests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có yêu cầu nào.'),
              ),
            )
          else
            ..._requests.map(_buildRequestCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu cầu thêm thời gian'),
        actions: [
          IconButton(
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                onPressed: _loadRequests,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : _buildContent(),
    );
  }
}
