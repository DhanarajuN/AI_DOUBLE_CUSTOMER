
class ServerUrls {
  ServerUrls._();

  static const String baseUrl = 'https://$tenant.dev.gosure.ai';

  static const String tenant = 'aidouble';

  static const String login = '/api/v1/users/login';

  static const String moduleConstants = '/api/v1/module-constants';


  static const String ssoCallbackScheme = 'aidoublecustomer';

  static const String ssoCallbackUrl = '$ssoCallbackScheme://auth-redirect';

  static const String ssoGoogleLogin = '/api/v1/sso/Google/login';

  static const String ssoSessionLogin = '/api/v1/users/sso/session-login';

 
  static const String librechatURL = 'https://librechat-backend-137691469700.asia-south1.run.app';

  static const String librechatAgents = '/api/agents/';

  static const String librechatAgentChat = '/api/agents/chat';

  static const String librechatAgentChatStream = '/api/agents/chat/stream/';

  static const String librechatConvos = '/api/convos';

  static const String librechatMessages = '/api/messages/';
}
