class ServerUrls {
  ServerUrls._();

  static const String baseUrl = 'https://$tenant.dev.gosure.ai';

  static const String tenant = 'aidouble';

  static const String login = '/api/v1/users/login';

  static const String users = '/api/v1/users';

  static const String usersUpdate = '/api/v1/users/update';

  static const String rolesByName = '/api/v1/roles/name';

  static const String moduleConstants = '/api/v1/module-constants';

  static const String ssoCallbackScheme = 'aidoublecustomer';

  static const String ssoCallbackUrl = '$ssoCallbackScheme://auth-redirect';

  static const String ssoGoogleLogin = '/api/v1/sso/Google/login';

  static const String ssoSessionLogin = '/api/v1/users/sso/session-login';

  static const String createInstancePublic = '/api/v1/public/create-instance';

  static const String createInstance = '/api/v1/job-instances';

  static const String bookingsInstances =
      '/api/v1/job-types/name/Bookings/instances';

  static const String membersInstances =
      '/api/v1/job-types/name/Members/instances';

  static const String businessInstances =
      '/api/v1/job-types/name/Business/instances';

  static const String jobInstances = '/api/v1/job-instances/';

  static const String updateWorkflowStatus =
      '/api/v1/job-instances/update-workflow-status';

  static const String attachmentsUpload = '/api/v1/attachments/upload';

  static const String attachmentsDownload = '/api/v1/attachments/download';

  static const String librechatURL = String.fromEnvironment(
    'LIBRECHAT_URL',
    defaultValue: 'https://librechat-backend-olj53mb3da-el.a.run.app',
  );

  static const String coreMcpUrl = String.fromEnvironment(
    'CORE_MCP_URL',
    defaultValue: 'https://dev.gosure.ai',
  );

  static const String librechatAgents = '/api/agents/';

  static const String librechatFilesImages = '/api/files/images';

  static const String librechatAgentChat = '/api/agents/chat';

  static const String librechatAgentChatStream = '/api/agents/chat/stream/';

  static const String librechatConvos = '/api/convos';

  static const String librechatMessages = '/api/messages/';

  static const String librechatSuggestReplies = '/api/agents/suggest-replies';

  // Persistent, always-open per-conversation event stream (business
  // handoff: message.created / agent-mode.changed) — distinct from
  // [librechatAgentChatStream], which is the per-turn generation stream.
  static const String gosureConvoEvents = '/api/gosure/convos/';

  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://ai-double-3daj2l7p.livekit.cloud',
  );

  static const String livekitHttpUrl = String.fromEnvironment(
    'LIVEKIT_HTTP_URL',
    defaultValue: 'https://ai-double-3daj2l7p.livekit.cloud',
  );
}
