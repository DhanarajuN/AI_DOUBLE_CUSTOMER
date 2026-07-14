import 'package:flutter/material.dart';
import '../views/agent_chat_view.dart';
import '../views/archived_view.dart';
import '../views/chat_list_view.dart';
import '../views/chat_thread_view.dart';
import '../views/login_view.dart';
import '../views/profile_view.dart';
import '../views/splash_view.dart';

/// Central named-route table for the whole app. Every screen push goes
/// through [onGenerateRoute] — via Navigator.pushNamed and friends — so
/// route names and their required arguments live in one place instead of
/// each call site constructing its own MaterialPageRoute.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String chatList = '/chats';
  static const String archived = '/chats/archived';

  /// Pass the conversation id as `arguments`.
  static const String chatThread = '/chats/thread';

  /// Pass an [AgentThreadArgs] as `arguments`.
  static const String agentThread = '/agents/thread';

  /// Pass the professional id as `arguments`.
  static const String profile = '/pro';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashView(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginView(), settings: settings);
      case chatList:
        return MaterialPageRoute(builder: (_) => const ChatListView(), settings: settings);
      case archived:
        return MaterialPageRoute(builder: (_) => const ArchivedView(), settings: settings);
      case chatThread:
        final convoId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => ChatThreadView(convoId: convoId), settings: settings);
      case agentThread:
        final args = settings.arguments as AgentThreadArgs;
        return MaterialPageRoute(
          builder: (_) => AgentChatView(
            agent: args.agent,
            initialConversationId: args.conversationId,
            initialMessages: args.initialMessages,
          ),
          settings: settings,
        );
      case profile:
        final proId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => ProfileView(proId: proId), settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for "${settings.name}"')),
          ),
          settings: settings,
        );
    }
  }
}
