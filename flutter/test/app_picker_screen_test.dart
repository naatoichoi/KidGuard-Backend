import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidguard/screens/parent/app_picker_screen.dart';

void main() {
  testWidgets(
    'Tìm bằng tên, chọn đúng app có thời gian bằng 0 mà không nhập package',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppPickerScreen(
                        apps: [
                          {
                            'packageName': 'com.google.android.youtube',
                            'appName': 'YouTube',
                            'durationSeconds': 120,
                          },
                          {
                            'packageName': 'com.zing.zalo',
                            'appName': 'Zalo',
                            'durationSeconds': 0,
                          },
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Chọn app'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chọn app'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zalo');
      await tester.pumpAndSettle();
      expect(find.text('YouTube'), findsNothing);
      expect(find.text('0 phút 0 giây hôm nay'), findsOneWidget);
      await tester.tap(find.text('Zalo'));
      await tester.pumpAndSettle();
      expect(selected, 'com.zing.zalo');
    },
  );
}
