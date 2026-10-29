import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A voluntary, foreground-only movement break. No screen-time rewards are issued.
class MotionBreakScreen extends StatefulWidget {
  const MotionBreakScreen({super.key});

  @override
  State<MotionBreakScreen> createState() => _MotionBreakScreenState();
}

class _MotionBreakScreenState extends State<MotionBreakScreen>
    with WidgetsBindingObserver {
  static const _channel = EventChannel('kidguard/motion');
  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;
  double _acceleration = 0;
  int _seconds = 0;
  int _activeSeconds = 0;
  bool _movedThisSecond = false;
  bool _running = false;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _stop() {
    _timer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _running = false;
  }

  void _start() {
    _stop();
    setState(() {
      _seconds = 0;
      _activeSeconds = 0;
      _movedThisSecond = false;
      _completed = false;
      _error = null;
      _running = true;
    });
    _subscription = _channel.receiveBroadcastStream().listen(
      (event) {
        if (!mounted || !_running) return;
        final axes = (event as List).cast<num>();
        final value = sqrt(
          axes.fold<double>(0, (sum, axis) => sum + axis * axis),
        );
        setState(() {
          _acceleration = value;
          if (value >= 1.5) _movedThisSecond = true;
        });
      },
      onError: (Object error) {
        _stop();
        if (mounted) setState(() => _error = 'Không đọc được cảm biến: $error');
      },
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() {
        _seconds++;
        if (_movedThisSecond) _activeSeconds++;
        _movedThisSecond = false;
        if (_seconds >= 30) {
          _completed = true;
          _stop();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _running) {
      _stop();
      if (mounted) {
        setState(
          () =>
              _error = 'Phiên đã dừng khi rời màn hình. Bấm bắt đầu để đo lại.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nghỉ mắt · Vận động 30 giây')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.self_improvement,
            size: 80,
            color: Color(0xFF6254D9),
          ),
          const SizedBox(height: 20),
          Text(
            'Một khoảng nghỉ cho con',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Rời mắt khỏi màn hình và đi bộ nhẹ tại chỗ, cầm điện thoại chắc tay. Cảm biến đo chuyển động của điện thoại trong phiên nghỉ.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '${_acceleration.toStringAsFixed(2)} m/s²',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text('Gia tốc tuyến tính · đã loại trọng lực'),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: _seconds / 30),
                  const SizedBox(height: 12),
                  Text(
                    '$_seconds / 30 giây · Có chuyển động: $_activeSeconds giây',
                  ),
                ],
              ),
            ),
          ),
          if (_completed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _activeSeconds >= 10
                    ? 'Hoàn thành phiên nghỉ! Con đã vận động trong ít nhất 10 giây.'
                    : 'Đã hết phiên nghỉ. Lần tới hãy vận động nhẹ nhiều hơn nhé.',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              _running ? 'Đang đo chuyển động…' : 'Bắt đầu phiên nghỉ',
            ),
          ),
          if (_running)
            TextButton(
              onPressed: () => setState(_stop),
              child: const Text('Dừng'),
            ),
        ],
      ),
    );
  }
}
