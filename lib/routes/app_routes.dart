import 'package:flutter/material.dart';
import '../services/app_logger.dart';
import '../views/agent_chat_view.dart';
import '../views/chat_list_view.dart';
import '../views/login_view.dart';
import '../views/splash_view.dart';

final routeObserver = RouteObserver<PageRoute<dynamic>>();

class AppNavigatorObserver extends NavigatorObserver {
  String _label(Route<dynamic>? route) => route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLogger.i('Navigation', 'push ${_label(route)} (from ${_label(previousRoute)})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLogger.i('Navigation', 'pop ${_label(route)} (back to ${_label(previousRoute)})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppLogger.i('Navigation', 'replace ${_label(oldRoute)} with ${_label(newRoute)}');
  }
}

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String chatList = '/chats';
  static const String agentThread = '/agents/thread';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashView(), settings: settings);
      case login:
        return MaterialPageRoute(builder: (_) => const LoginView(), settings: settings);
      case chatList:
        return MaterialPageRoute(builder: (_) => const ChatListView(), settings: settings);
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
