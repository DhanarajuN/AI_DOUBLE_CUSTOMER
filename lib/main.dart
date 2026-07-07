import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'repositories/convo_repository.dart';
import 'repositories/pro_repository.dart';
import 'repositories/script_repository.dart';
import 'theme/app_theme.dart';
import 'views/chat_list_view.dart';

void main() {
  runApp(const AiDoubleApp());
}

class AiDoubleApp extends StatelessWidget {
  const AiDoubleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Data layer — swap these for API-backed implementations later;
        // nothing above this layer needs to change.
        Provider<ProRepository>(create: (_) => StaticProRepository()),
        Provider<ScriptRepository>(create: (_) => StaticScriptRepository()),
        ChangeNotifierProvider<ConvoRepository>(
          create: (ctx) => ConvoRepository(ctx.read<ScriptRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'AI Double Customer',
        debugShowCheckedModeBanner: false,
        // Global theme/fonts (lib/theme/app_theme.dart) — change once here
        // and the whole app updates.
        theme: buildAppTheme(),
        home: const ChatListView(),
      ),
    );
  }
}
