import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'config/api_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/parent/parent_home_screen.dart';
import 'screens/child/child_home_screen.dart';
import 'services/appearance_settings.dart';
import 'services/auth_service.dart';
import 'services/child_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  final appearance = AppearanceSettings();
  await appearance.load();

  debugPrint('[KidGuard] main() started');

  runApp(KidGuardApp(appearance: appearance));
}

class KidGuardApp extends StatelessWidget {
  const KidGuardApp({super.key, required this.appearance});
  final AppearanceSettings appearance;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appearance,
      child: Consumer<AppearanceSettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'phamngocanh2380600070',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.from(background: settings.background),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.fontScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SessionGate(),
          );
        },
      ),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<String?> _roleFuture = _loadRole();

  Future<String?> _loadRole() async {
    if (await const FlutterSecureStorage().read(key: 'kidguard_signed_out') ==
        'true') {
      return null;
    }
    if (await AuthService().getValidRole() == 'Parent') return 'Parent';
    debugPrint('[KidGuard] Checking saved session...');

    try {
      final childAuth = ChildAuthService();
      final hasDevice = await childAuth.hasPairedDevice();
      if (hasDevice) {
        debugPrint('[KidGuard] Paired Child device detected');
        return 'Child';
      }
    } catch (e) {
      debugPrint('[KidGuard] Child session check failed: $e');
    }

    try {
      final role = await AuthService().getValidRole().timeout(
        const Duration(seconds: 10),
      );
      debugPrint('[KidGuard] Session role: $role');
      return role;
    } catch (e, stackTrace) {
      debugPrint('[KidGuard] Session check failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == 'Child') {
          return const ChildHomeScreen();
        }

        if (snapshot.data == 'Parent') {
          return const ParentHomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
