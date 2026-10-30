import 'package:flutter/material.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.apps, this.selectedPackage});
  final List<Map<String, dynamic>> apps;
  final String? selectedPackage;
  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  String _query = '';
  String _used(Map<String, dynamic> app) {
    final seconds = (app['durationSeconds'] as num?)?.toInt() ?? 0;
    return '${seconds ~/ 60} phút ${seconds % 60} giây hôm nay';
  }

  @override
  Widget build(BuildContext context) {
    final apps = widget.apps
        .where(
          (app) => (app['appName']?.toString() ?? '').toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn ứng dụng trên máy trẻ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm theo tên ứng dụng',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: apps.isEmpty
                ? const Center(child: Text('Không tìm thấy ứng dụng phù hợp.'))
                : ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final name = app['appName']?.toString() ?? 'Ứng dụng';
                      final duplicateName =
                          widget.apps
                              .where((a) => a['appName'] == name)
                              .length >
                          1;
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.apps)),
                        title: Text(name),
                        subtitle: Text(
                          '${_used(app)}${duplicateName ? '\n${app['packageName']}' : ''}',
                        ),
                        trailing: app['packageName'] == widget.selectedPackage
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.indigo,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(
                          context,
                          app['packageName'].toString(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
