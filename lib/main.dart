import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'constants/server_urls.dart';
import 'repositories/auth_repository.dart';
import 'repositories/convo_repository.dart';
import 'repositories/pro_repository.dart';
import 'repositories/script_repository.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AiDoubleApp());
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
        // Data layer — swap these for API-backed implementations later;
        // nothing above this layer needs to change.
        Provider<ProRepository>(create: (_) => StaticProRepository()),
        Provider<ScriptRepository>(create: (_) => StaticScriptRepository()),
        ChangeNotifierProvider<ConvoRepository>(
          create: (ctx) => ConvoRepository(ctx.read<ScriptRepository>()),
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
      ),
    );
  }
}
