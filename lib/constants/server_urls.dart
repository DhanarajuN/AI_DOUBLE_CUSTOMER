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

  static const String createInstance = '/api/v1/public/create-instance';

  static const String bookingsInstances = '/api/v1/job-types/name/Bookings/instances';

  static const String librechatURL = 'https://librechat-backend-olj53mb3da-el.a.run.app';

  static const String librechatAgents = '/api/agents/';

  static const String librechatFilesImages = '/api/files/images';

  static const String librechatAgentChat = '/api/agents/chat';

  static const String librechatAgentChatStream = '/api/agents/chat/stream/';

  static const String librechatConvos = '/api/convos';

  static const String librechatMessages = '/api/messages/';
}
