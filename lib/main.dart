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

class AiDoubleApp extends StatelessWidget {
  const AiDoubleApp({super.key});

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
