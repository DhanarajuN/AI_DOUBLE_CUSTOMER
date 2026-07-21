import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'constants/server_urls.dart';
import 'repositories/auth_repository.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/app_logger.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppLogger.init();

    FlutterError.onError = (details) {
      AppLogger.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e('PlatformDispatcher', 'Uncaught async error', error, stack);
      return true;
    };

    runApp(const AiDoubleApp());
  }, (error, stack) {
    AppLogger.e('runZonedGuarded', 'Uncaught zone error', error, stack);
  });
}

class AiDoubleApp extends StatefulWidget {
  const AiDoubleApp({super.key});

  @override
  State<AiDoubleApp> createState() => _AiDoubleAppState();
}

class _AiDoubleAppState extends State<AiDoubleApp> with WidgetsBindingObserver {
  Brightness _lastBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  Timer? _brightnessPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Some OEM Android builds (confirmed on this test device) don't
    // reliably deliver the platform-brightness config-change callback to
    // didChangePlatformBrightness below, so poll as a fallback — this is
    // what actually makes live theme switching work everywhere, not just
    // on devices where the callback behaves.
    _brightnessPoll = Timer.periodic(const Duration(seconds: 1), (_) => _checkBrightness());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brightnessPoll?.cancel();
    super.dispose();
  }

  void _checkBrightness() {
    final current = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (current != _lastBrightness) {
      _lastBrightness = current;
      // A plain setState() here only rebuilds the initial route — Flutter
      // doesn't reliably cascade an ancestor rebuild into already-built
      // *pushed* Navigator routes (confirmed: the chat list picked up a
      // theme change live, but an already-open conversation page didn't).
      // reassembleApplication() is the same mechanism hot-reload uses to
      // force every widget in the tree to rebuild, regardless of Navigator
      // depth, without losing any State (so you don't lose your place in
      // the conversation).
      setState(() {});
      WidgetsBinding.instance.reassembleApplication();
    }
  }

  // Rebuilds the tree when the device's light/dark setting changes, so
  // AppColors (theme/app_theme.dart) — read fresh on every build — picks
  // up the new brightness without needing an app restart.
  @override
  void didChangePlatformBrightness() => _checkBrightness();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.i('Lifecycle', state.name);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Shared HTTP layer for future Api*Repository implementations —
        // update baseUrl once the backend is ready.
        Provider<ApiClient>(
          create: (_) => ApiClient(baseUrl: ServerUrls.baseUrl, tenant: ServerUrls.tenant),
          dispose: (_, client) => client.close(),
        ),
        Provider<SessionStorage>(create: (_) => SessionStorage()),
        ChangeNotifierProvider<AuthRepository>(
          create: (ctx) => AuthRepository(ctx.read<ApiClient>(), ctx.read<SessionStorage>()),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        // Global theme/fonts (lib/theme/app_theme.dart) — change once here
        // and the whole app updates.
        theme: buildAppTheme(),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        navigatorObservers: [AppNavigatorObserver()],
      ),
    );
  }
}
