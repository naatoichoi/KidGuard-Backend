import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../common/notifications_screen.dart';
import 'child_location_map_screen.dart';
import 'child_usage_report_screen.dart';
import 'parent_pairing_screen.dart';
import 'screen_time_limits_screen.dart';
import 'time_requests_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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

  List<Map<String, dynamic>> get _children {
    final raw = _dashboard?['children'];
    if (raw is! List) return [];
    return raw.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.get('Dashboard/parent');
      if (!mounted) return;
      setState(() {
        _dashboard = Map<String, dynamic>.from(response as Map);
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

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) await _loadDashboard();
  }

  void _invalidId() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID không hợp lệ.')),
    );
  }

  void _openLocation(Map<String, dynamic> child) {
    final id = _toInt(child['childId']);
    if (id <= 0) return _invalidId();
    _openScreen(ChildLocationMapScreen(
      childId: id,
      childName: child['childName']?.toString() ?? 'Child',
    ));
  }

  void _openUsageReport(Map<String, dynamic> child) {
    final id = _toInt(child['childId']);
    if (id <= 0) return _invalidId();
    _openScreen(ChildUsageReportScreen(
      childId: id,
      childName: child['childName']?.toString() ?? 'Child',
    ));
  }

  void _openLimits(Map<String, dynamic> device) {
    final id = _toInt(device['deviceId']);
    if (id <= 0) return _invalidId();
    _openScreen(ScreenTimeLimitsScreen(
      deviceId: id,
      deviceName: device['deviceName']?.toString() ?? 'Thiết bị',
    ));
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(
            fontSize: 27, fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(
            fontSize: 13, color: Colors.black54,
          )),
        ],
      ),
    );
  }

  Widget _deviceCard(Map<String, dynamic> device) {
    final used = _toInt(device['usedMinutes']);
    final rawLimit = device['effectiveLimitMinutes'];
    final int? limit = rawLimit == null ? null : _toInt(rawLimit);
    final remaining = _toInt(device['remainingMinutes']);
    final extra = _toInt(device['extraMinutes']);
    final exceeded = limit != null && limit > 0 && used >= limit;
    final progress = limit == null || limit <= 0
        ? 0.0 : (used / limit).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.smartphone, color: Color(0xFF6254D9)),
            const SizedBox(width: 10),
            Expanded(child: Text(
              device['deviceName']?.toString() ?? 'Thiết bị',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            )),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Đã sử dụng'),
            Text('$used phút', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: const Color(0xFFE4E5ED),
            color: exceeded ? Colors.red : const Color(0xFF6254D9),
          ),
          const SizedBox(height: 12),
          if (limit == null || limit <= 0)
            const Text('Chưa có giới hạn tổng thời gian đang áp dụng.',
                style: TextStyle(color: Colors.black54))
          else ...[
            Text('Giới hạn: $limit phút'),
            const SizedBox(height: 5),
            Text(exceeded ? 'Đã đạt hoặc vượt giới hạn'
                : 'Còn lại: $remaining phút',
                style: TextStyle(
                  color: exceeded ? Colors.red : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                )),
            if (extra > 0) ...[
              const SizedBox(height: 5),
              Text('Đã cộng thêm: $extra phút'),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => _openLimits(device),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Thiết lập giới hạn'),
          )),
        ],
      ),
    );
  }

  Widget _childCard(Map<String, dynamic> child) {
    final name = child['childName']?.toString() ?? 'Child';
    final used = _toInt(child['totalUsedMinutes']);
    final rawDevices = child['devices'];
    final devices = rawDevices is List ? rawDevices : [];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFEAE7FF),
                child: Icon(Icons.child_care, color: Color(0xFF6254D9)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Text('Đã dùng: $used phút',
                      style: const TextStyle(color: Colors.black54)),
                ],
              )),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () => _openUsageReport(child),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Xem thống kê sử dụng'),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => _openLocation(child),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Xem vị trí GPS'),
            )),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Chưa có thiết bị được liên kết.'),
              )
            else
              ...devices.whereType<Map>().map((device) =>
                  _deviceCard(Map<String, dynamic>.from(device))),
          ],
        ),
      ),
    );
  }

  Widget _dashboardView() {
    final data = _dashboard!;
    final children = _children;
    final pending = _toInt(data['pendingRequests']);
    final unread = _toInt(data['unreadNotifications']);
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tổng quan gia đình', style: Theme.of(context)
              .textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Ngày ${data['date'] ?? ''}',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard('Trẻ em', _toInt(data['totalChildren']),
                  Icons.family_restroom, Colors.blue),
              _statCard('Thiết bị', _toInt(data['totalDevices']),
                  Icons.devices, Colors.purple),
              _statCard('Chờ duyệt', pending,
                  Icons.schedule, Colors.orange),
              _statCard('Thông báo mới', unread,
                  Icons.notifications_outlined, Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFEAE7FF),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner,
                    color: Color(0xFF6254D9)),
                title: const Text('Ghép thiết bị bằng QR',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Quét mã QR trên thiết bị Child'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openScreen(
                  ParentPairingScreen(children: _children),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.pending_actions,
                    color: Color(0xFF6254D9)),
                title: const Text('Yêu cầu thêm thời gian',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(pending > 0
                    ? '$pending yêu cầu đang chờ'
                    : 'Xem yêu cầu và lịch sử phê duyệt'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openScreen(const TimeRequestsScreen()),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          const Text('Danh sách con', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 14),
          if (children.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có Child được liên kết với tài khoản.'),
            ))
          else
            ...children.map(_childCard),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(_error ?? 'Đã xảy ra lỗi.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loadDashboard,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final unread = _toInt(_dashboard?['unreadNotifications']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('KidGuard · Phụ huynh',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Stack(alignment: Alignment.center, children: [
            IconButton(
              onPressed: () => _openScreen(const NotificationsScreen()),
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Thông báo',
            ),
            if (unread > 0)
              Positioned(
                right: 7, top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ),
          ]),
          IconButton(onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout,
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : _dashboard == null
          ? const Center(child: Text('Chưa có dữ liệu Dashboard.'))
          : _dashboardView(),
    );
  }
}
