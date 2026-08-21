import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import '../firebase_options.dart';
import '../routes/app_routes.dart';
import '../views/agent_chat_view.dart';
import 'app_logger.dart';
import 'librechat_service.dart';
import 'session_storage.dart';

/// Must be a top-level (or static) function — the FCM plugin runs it in a
/// separate background isolate when a data message arrives while the app is
/// backgrounded/terminated, so it can't close over any app state. A
/// `notification` payload (which this service always sends, see
/// pushNotifications.js on the backend) is displayed by the OS itself in
/// this state without any app code running at all; this handler only exists
/// so `data`-only messages would still be handled if that ever changes.
@pragma('vm:entry-point')
Future<void> gosureBackgroundMessageHandler(RemoteMessage message) async {
  AppLogger.i('PushNotification', 'Background message: ${message.messageId}');
}

/// WhatsApp-style push notifications for the Customer app: an agent reply
/// or a business's direct message buzzes the phone when the relevant
/// conversation isn't already open (server-side presence check — see
/// presence.js on the backend; nothing here needs to report "I'm viewing
/// this", the existing SSE connection already is that signal).
///
/// Android + web only for now — this app has no ios/ project yet, so there
/// is nothing to configure Firebase against on iOS until that's scaffolded
/// separately.
class PushNotificationService {
  PushNotificationService._();
  static final _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  static final _sessionStorage = SessionStorage();
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;
  String? _lastKnownToken;

  static const _androidChannel = AndroidNotificationChannel(
    'gosure_customer_messages',
    'Messages',
    description: 'New messages on your conversations',
    importance: Importance.high,
  );

  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      // Guards against any future regeneration leaving this stale/missing —
      // every other feature in this app must keep working regardless.
      AppLogger.e('PushNotification', 'Firebase.initializeApp failed — push notifications disabled', e, st);
      return;
    }
    _initialized = true;

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(gosureBackgroundMessageHandler);
    }

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
      await _localNotifications.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) => _openFromPayload(response.payload),
      );
    }

    // Foreground: FCM never shows a system notification on its own while the
    // app is in the foreground (by design, on both platforms) — that's what
    // flutter_local_notifications here is for on Android; on web the
    // notification permission prompt/display is handled by the browser
    // itself via the service worker, so this listener there is just for the
    // in-app data (e.g. a future in-app banner), not a duplicate OS popup.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      if (kIsWeb) return;
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(_androidChannel.id, _androidChannel.name,
              channelDescription: _androidChannel.description, importance: Importance.high, priority: Priority.high),
        ),
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) => _openFromData(message.data));
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openFromData(initialMessage.data);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      AppLogger.i('PushNotification', 'FCM token refreshed');
      _registerToken(token);
    });
  }

  void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _openFromData((jsonDecode(payload) as Map).cast<String, dynamic>());
    } catch (e) {
      AppLogger.w('PushNotification', 'Could not parse notification payload: $e');
    }
  }

  Future<void> _openFromData(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'] as String?;
    AppLogger.i('PushNotification', 'Opening from notification, conversationId=$conversationId');

    final context = navigatorKey.currentContext;
    if (conversationId != null && conversationId.isNotEmpty && context != null) {
      try {
        final convo = await LibreChatService.fetchConversation(conversationId);
        final agentId = convo?['agent_id'] as String?;
        if (convo != null && agentId != null && context.mounted) {
          navigatorKey.currentState?.pushNamed(AppRoutes.chatList);
          await AgentChatView.openExisting(
            context,
            conversationId: conversationId,
            agentId: agentId,
            businessId: convo['businessId'] as String?,
            initialAgentChatMode: convo['agentChatMode'] as bool? ?? true,
          );
          return;
        }
      } catch (e, st) {
        AppLogger.e('PushNotification', 'Could not fetch conversation for deep link', e, st);
      }
    }
    // Fallback: couldn't resolve the specific conversation (not found, or
    // the fetch failed) — still land somewhere real and useful rather than
    // nowhere.
    navigatorKey.currentState?.pushNamed(AppRoutes.chatList);
  }

  /// Call once, right after a successful login/session restore.
  Future<void> registerForCurrentUser() async {
    if (_initializing != null) await _initializing;
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (e, st) {
      AppLogger.e('PushNotification', 'Could not get/register FCM token', e, st);
    }
  }

  Future<void> _registerToken(String token) async {
    _lastKnownToken = token;
    final accessToken = await _sessionStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.gosureConvoEvents}push/register'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode({
          'token': token,
          'platform': kIsWeb ? 'web' : 'android',
          'app': 'customer',
        }),
      );
      AppLogger.i('PushNotification', 'Register push token -> ${res.statusCode}');
    } catch (e, st) {
      AppLogger.e('PushNotification', 'Failed to register push token', e, st);
    }
  }

  /// Call on sign-out — a shared/reset device must stop receiving the
  /// signed-out account's notifications.
  Future<void> unregister() async {
    final token = _lastKnownToken;
    if (token == null) return;
    final accessToken = await _sessionStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    try {
      await http.post(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.gosureConvoEvents}push/unregister'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode({'token': token}),
      );
    } catch (e, st) {
      AppLogger.e('PushNotification', 'Failed to unregister push token', e, st);
    } finally {
      _lastKnownToken = null;
    }
  }
}
