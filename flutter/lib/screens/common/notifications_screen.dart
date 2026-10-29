import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../parent/child_location_map_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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

  bool _isRead(Map<String, dynamic> notification) {
    return notification['isRead'] == true;
  }

  List<Map<String, dynamic>> _parseNotifications(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (response is Map) {
      for (final key in ['notifications', 'items', 'data']) {
        if (response[key] is List) {
          return _parseNotifications(response[key]);
        }
      }
    }

    return [];
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.get('Notifications');

      if (!mounted) return;

      setState(() {
        _notifications = _parseNotifications(response);
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

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = _toInt(notification['id']);

    if (id <= 0 || _isRead(notification)) return;
    if (_processingIds.contains(id)) return;

    setState(() {
      _processingIds.add(id);
    });

    try {
      await _api.put('Notifications/$id/read');

      if (!mounted) return;

      setState(() {
        notification['isRead'] = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể đánh dấu đã đọc: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(id);
        });
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)} '
        '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year}';
  }

  IconData _notificationIcon(String type) {
    final value = type.toUpperCase();

    if (value.contains('TIME') || value.contains('LIMIT')) {
      return Icons.access_time;
    }

    if (value.contains('LOCATION')) {
      return Icons.location_on_outlined;
    }

    if (value.contains('PAIR')) {
      return Icons.devices;
    }

    return Icons.notifications_outlined;
  }

  Widget _notificationCard(Map<String, dynamic> notification) {
    final id = _toInt(notification['id']);
    final isRead = _isRead(notification);
    final processing = _processingIds.contains(id);

    final title = notification['title']?.toString() ?? 'Thông báo';

    final message = notification['message']?.toString() ?? '';

    final type = notification['type']?.toString() ?? '';

    final createdAt = _formatDate(notification['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : const Color(0xFFF0EDFF),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: processing
            ? null
            : () async {
                if (!isRead) await _markAsRead(notification);
                if (!mounted) return;
                if (type == 'LOCATION_SHARED') {
                  final childId = _toInt(notification['referenceId']);
                  if (childId > 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ChildLocationMapScreen(
                          childId: childId,
                          childName: 'Con',
                        ),
                      ),
                    );
                  }
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isRead
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFFE0D9FF),
                child: Icon(
                  _notificationIcon(type),
                  color: const Color(0xFF6254D9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          const Icon(
                            Icons.circle,
                            color: Color(0xFF6254D9),
                            size: 9,
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(message),
                    ],
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (!isRead) ...[
                      const SizedBox(height: 8),
                      Text(
                        processing
                            ? 'Đang cập nhật...'
                            : 'Nhấn để đánh dấu đã đọc',
                        style: const TextStyle(
                          color: Color(0xFF6254D9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final unreadCount = _notifications.where((item) => !_isRead(item)).length;

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Thông báo của bạn',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            unreadCount > 0
                ? '$unreadCount thông báo chưa đọc'
                : 'Bạn đã đọc tất cả thông báo',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          if (_notifications.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 48,
                      color: Colors.black38,
                    ),
                    SizedBox(height: 12),
                    Text('Chưa có thông báo nào.'),
                  ],
                ),
              ),
            )
          else
            ..._notifications.map(_notificationCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
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
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadNotifications,
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
