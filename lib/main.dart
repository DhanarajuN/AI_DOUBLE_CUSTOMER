import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_list_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AiDoubleApp());
}

class AiDoubleApp extends StatelessWidget {
  const AiDoubleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'AI Double',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const ChatListScreen(),
      ),
    );
  }
}
