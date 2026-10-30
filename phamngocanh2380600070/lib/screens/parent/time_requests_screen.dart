
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class TimeRequestsScreen extends StatefulWidget {
  const TimeRequestsScreen({super.key});

  @override
  State<TimeRequestsScreen> createState() =>
      _TimeRequestsScreenState();
}

class _TimeRequestsScreenState extends State<TimeRequestsScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _history = [];

  bool _loading = true;
  int? _processingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
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
      final pendingResponse =
      await _api.get('TimeRequests/pending');

      final historyResponse =
      await _api.get('TimeRequests/history');

      if (!mounted) return;

      setState(() {
        _pending = _toList(pendingResponse);
        _history = _toList(historyResponse);
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

  Future<void> _processRequest({
    required int requestId,
    required bool approve,
  }) async {
    if (_processingId != null) return;

    setState(() => _processingId = requestId);

    try {
      await _api.put(
        'TimeRequests/$requestId/${approve ? 'approve' : 'reject'}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Đã phê duyệt yêu cầu.'
                : 'Đã từ chối yêu cầu.',
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
        setState(() => _processingId = null);
      }
    }
  }

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Đang chờ';
      case 'APPROVED':
        return 'Đã duyệt';
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

  Widget _requestCard(
      Map<String, dynamic> request, {
        required bool pending,
      }) {
    final requestId = _toInt(request['id']);
    final minutes = _toInt(request['requestedMinutes']);
    final status = request['status']?.toString() ??
        (pending ? 'PENDING' : '');

    final childName =
        request['childName']?.toString() ?? 'Trẻ em';

    final reason = request['reason']?.toString() ?? '';

    final processing = _processingId == requestId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAE7FF),
                  child: Icon(
                    Icons.child_care,
                    color: Color(0xFF6254D9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    childName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatStatus(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Xin thêm $minutes phút',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Lý do: $reason'),
            ],
            if (request['deviceName'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Thiết bị: ${request['deviceName']}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: processing || _processingId != null
                          ? null
                          : () => _processRequest(
                        requestId: requestId,
                        approve: false,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: processing || _processingId != null
                          ? null
                          : () => _processRequest(
                        requestId: requestId,
                        approve: true,
                      ),
                      icon: processing
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.check),
                      label: const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Yêu cầu đang chờ (${_pending.length})',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Không có yêu cầu đang chờ duyệt.'),
              ),
            )
          else
            ..._pending.map(
                  (request) => _requestCard(
                request,
                pending: true,
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Lịch sử yêu cầu',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có lịch sử yêu cầu.'),
              ),
            )
          else
            ..._history.map(
                  (request) => _requestCard(
                request,
                pending: false,
              ),
            ),
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
