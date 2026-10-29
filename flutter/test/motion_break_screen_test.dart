import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidguard/screens/child/motion_break_screen.dart';

void main() {
  const channel = EventChannel('kidguard/motion');

  testWidgets('Báo lỗi thiếu cảm biến và dừng bộ đếm', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.error(code: 'UNAVAILABLE', message: 'Không có cảm biến');
        },
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: MotionBreakScreen()));
    await tester.tap(find.text('Bắt đầu phiên nghỉ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Không đọc được cảm biến'), findsOneWidget);
    expect(find.textContaining('0 / 30 giây'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Rời ứng dụng hủy cảm biến và không tiếp tục tính thời gian', (
    tester,
  ) async {
    bool cancelled = false;
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, events) => events.success([3.0, 4.0, 0.0]),
        onCancel: (_) => cancelled = true,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: MotionBreakScreen()));
    await tester.tap(find.text('Bắt đầu phiên nghỉ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('5.00 m/s²'), findsOneWidget);
    expect(
      find.textContaining('1 / 30 giây · Có chuyển động: 1 giây'),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(cancelled, isTrue);
    expect(find.textContaining('1 / 30 giây'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
