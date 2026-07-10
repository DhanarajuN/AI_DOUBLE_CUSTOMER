
class ServerUrls {
  ServerUrls._();

  static const String baseUrl = 'https://$tenant.dev.gosure.ai';

  static const String tenant = 'devtesting';

  static const String login = '/api/v1/users/login';

  // LibreChat backend — separate service used only for the background
  // token login on app start (see services/librechat_service.dart).
  static const String librechatURL = 'https://librechat-backend-166239710803.asia-south1.run.app';

  static const String librechatLogin = '/api/auth/login';

  static const String librechatAgents = '/api/agents/';

  static const String librechatAgentChat = '/api/agents/chat';

  static const String librechatAgentChatStream = '/api/agents/chat/stream/';
}
