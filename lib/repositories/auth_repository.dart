import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import '../models/user.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/session_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

// The SSO server builds this display name as "firstName lastName" and stringifies
// a missing lastName as the literal word "null" (e.g. "Hitesh null") rather than
// omitting it — strip that off here so it never reaches the UI or another user's
// screen via senderName.
String _cleanName(String raw) {
  final cleaned =
      raw.replaceAll(RegExp(r'\s+null\b', caseSensitive: false), '').trim();
  return cleaned.isEmpty ? raw.trim() : cleaned;
}

/// Session/auth state shared across the app. Wraps [ApiClient] for the
/// login request and [SessionStorage] to persist the result across app
/// restarts — [SplashView] calls [restoreSession] once, before deciding
/// whether to route to login or the chat list.
class AuthRepository extends ChangeNotifier {
  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  AuthRepository(this._apiClient, this._sessionStorage) {
    _apiClient.onUnauthorized = _handleSessionExpired;
  }

  bool _handlingExpiry = false;

  AuthStatus _status = AuthStatus.unknown;
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Comma-separated ACTIVE_AGENTS names from /api/v1/module-constants —
  // null until fetched (or if the fetch fails), which widgets/
  // new_request_sheet.dart treats as "no filter, show everything" rather
  // than hiding every agent.
  List<String>? _activeAgentNames;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String>? get activeAgentNames => _activeAgentNames;

  Future<void> restoreSession() async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      _apiClient.setAccessToken(session.accessToken);
      _currentUser = session.user;
      _status = AuthStatus.authenticated;
      await fetchModuleConstants();
    }
    notifyListeners();
  }

  Future<void> fetchModuleConstants() async {
    try {
      final json = await _apiClient.get(ServerUrls.moduleConstants)
          as Map<String, dynamic>;
      final moduleConstants = json['moduleConstants'] as List?;
      final first = (moduleConstants != null && moduleConstants.isNotEmpty)
          ? moduleConstants[0] as Map<String, dynamic>
          : null;
      final data = first?['data'] as Map<String, dynamic>?;
      final activeAgents = data?['ACTIVE_AGENTS'] as String?;
      _activeAgentNames = activeAgents
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e, st) {
      AppLogger.e('AuthRepository', 'fetchModuleConstants failed', e, st);
    }
  }

  Future<bool> login(
      {required String username, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final json = await _apiClient.post(ServerUrls.login, body: {
        'username': username,
        'password': password,
      }) as Map<String, dynamic>;

      await _completeLogin(
        accessToken: json['accessToken'] as String,
        token: json['token'] as String,
        userId: json['userId'] as String,
        name: json['Name'] as String,
        username: json['username'] as String,
        roleName: json['accRoleName'] as String,
      );
      AppLogger.i('AuthRepository', 'login succeeded for $username');
      return true;
    } on ApiException catch (e) {
      AppLogger.w('AuthRepository', 'login failed for $username: ${e.message}');
      _errorMessage = e.message;
      return false;
    } catch (e, st) {
      AppLogger.e('AuthRepository', 'login failed for $username', e, st);
      _errorMessage =
          'Could not reach the server. Check your connection and try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final authUrl =
          Uri.parse('${ServerUrls.baseUrl}${ServerUrls.ssoGoogleLogin}')
              .replace(queryParameters: {
        'tenantName': ServerUrls.tenant,
        'redirectUrl': ServerUrls.ssoCallbackUrl,
      });

      final callback = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: ServerUrls.ssoCallbackScheme,
      );
      final callbackUri = Uri.parse(callback);

      final error = callbackUri.queryParameters['error'];
      if (error != null) {
        AppLogger.w(
            'AuthRepository', 'Google sign-in returned an error: $error');
        _errorMessage = callbackUri.queryParameters['error_description'] ??
            'Google sign-in failed.';
        return false;
      }
      final sessionId = callbackUri.queryParameters['sessionId'];
      if (sessionId == null) {
        AppLogger.w(
            'AuthRepository', 'Google sign-in callback had no sessionId');
        _errorMessage = 'Google sign-in did not return a session.';
        return false;
      }

      final json = await _apiClient.post(
        ServerUrls.ssoSessionLogin,
        query: {'sessionId': sessionId},
      ) as Map<String, dynamic>;

      await _completeLogin(
        accessToken: json['token'] as String,
        token: json['token'] as String,
        userId: json['accountUserId'] as String,
        name: json['Name'] as String,
        username: json['username'] as String,
        roleName: json['accRoleName'] as String,
      );
      AppLogger.i('AuthRepository', 'Google sign-in succeeded');
      await _ensureMemberRecord(
          json['username'] as String, json['token'] as String);
      return true;
    } on PlatformException catch (e) {
      // User closed the browser tab / cancelled the Google sign-in.
      AppLogger.i('AuthRepository', 'Google sign-in cancelled: ${e.code}');
      return false;
    } on ApiException catch (e) {
      AppLogger.w('AuthRepository',
          'Google sign-in token exchange failed: ${e.message}');
      _errorMessage = e.message;
      return false;
    } catch (e, st) {
      AppLogger.e(
          'AuthRepository', 'Google sign-in failed unexpectedly', e, st);
      _errorMessage = 'Could not complete Google sign-in. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// authenticate the [ApiClient], and load ACTIVE_AGENTS.
  Future<void> _completeLogin({
    required String accessToken,
    required String token,
    required String userId,
    required String name,
    required String username,
    required String roleName,
  }) async {
    final user = User(
        id: userId,
        name: _cleanName(name),
        username: username,
        roleName: roleName);
    await _sessionStorage.saveSession(
        accessToken: accessToken, token: token, user: user);
    _apiClient.setAccessToken(accessToken);
    _currentUser = user;
    _status = AuthStatus.authenticated;
    await fetchModuleConstants();

    // Every login from this app should carry whatever role is configured for
    // it, regardless of what the account's SSO-created default role was.
    // Fire-and-forget, NOT awaited: this must never block the login that
    // already succeeded, even if the promotion calls hang outright (not just
    // fail fast) — hence the explicit timeout as a hard ceiling.
    unawaited(
      _promoteConfiguredRole(userId)
          .timeout(const Duration(seconds: 10))
          .catchError((e) {
        AppLogger.w('AuthRepository', 'Could not promote user role: $e');
      }),
    );
  }

  /// Looks up which role this app's logins should get from a Configurations
  /// instance keyed by this app's own SSO callback scheme — not hardcoded —
  /// the same mechanism ongo-core's own resolveDefaultRole uses for the
  /// tenant-wide "Default Role" config, just keyed per-app instead of
  /// per-tenant. Then fetches the user's current record and echoes it back
  /// with roleId, accountRole, and roleName all changed — PUT
  /// /api/v1/users/update/:id (ongo-core's UserController#mapFieldsAndUpdateUser)
  /// overwrites firstName/lastName/roleId/routerUrl/mobile/mobileCountryCode/data
  /// unconditionally, even when absent from the request body, so a roleId-only
  /// payload would blank those out — and leaves the denormalized accountRole and
  /// roleName stale at the old role if not also set explicitly. roleName follows
  /// the "<RoleName>(<roleId>)" format used by every SSO-created user record.
  Future<void> _promoteConfiguredRole(String userId) async {
    final roleName =
        await _resolveConfiguredRoleName(ServerUrls.ssoCallbackScheme);
    if (roleName == null) {
      throw Exception(
        'No Configurations entry named "${ServerUrls.ssoCallbackScheme}" (Name field) for this tenant',
      );
    }

    final roleResult = await _apiClient.get('/api/v1/roles/name/$roleName');
    final roleId = roleResult is Map ? roleResult['id'] as String? : null;
    if (roleId == null) {
      throw Exception('Role "$roleName" not found for this tenant');
    }

    final userResult = await _apiClient.get('/api/v1/users/$userId');
    if (userResult is! Map<String, dynamic>) {
      throw Exception('Unexpected response fetching user $userId');
    }

    final existingAccountRole = userResult['accountRole'];
    final accountRole = <String, dynamic>{
      if (existingAccountRole is Map)
        ...existingAccountRole.cast<String, dynamic>(),
      'id': roleId,
      'name': roleName,
    };
    final updated = Map<String, dynamic>.from(userResult)
      ..['roleId'] = roleId
      ..['accountRole'] = accountRole
      ..['roleName'] = '$roleName($roleId)';
    await _apiClient.put('/api/v1/users/update/$userId', body: updated);
    AppLogger.i('AuthRepository', 'Promoted user $userId to $roleName');
  }

  /// Looks up a Configurations instance by its Name field and returns
  /// string_value, via core-mcp's direct-query endpoint rather than
  /// ongo-core's public REST list endpoint — the latter applies workflow/ACL
  /// filtering that excludes these records.
  Future<String?> _resolveConfiguredRoleName(String configKey) async {
    final uri = Uri.parse(
        '${ServerUrls.coreMcpUrl}/core-mcp/configurations/${Uri.encodeComponent(configKey)}');
    final response = await http.get(
      uri,
      headers: {
        if (_apiClient.accessToken != null)
          'Authorization': 'Bearer ${_apiClient.accessToken}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'GET core-mcp configurations ${response.statusCode}: ${response.body}');
    }
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['found'] != true) {
      throw Exception(
          'Configurations entry "$configKey" not found (core-mcp response: ${response.body})');
    }
    final value = body['value'];
    return (value is String && value.trim().isNotEmpty) ? value.trim() : null;
  }

  Future<void> _ensureMemberRecord(String email, String accessToken) async {
    try {
      final filters = jsonEncode([
        {'fieldName': 'Email', 'condition': 'contains', 'value': email},
      ]);
      final json = await _apiClient.get(
        ServerUrls.membersInstances,
        query: {'pageNumber': '1', 'pageSize': '10', 'filters': filters},
      ) as Map<String, dynamic>;
      final jobs = json['jobs'] as List?;
      if (jobs != null && jobs.isNotEmpty) {
        AppLogger.i('AuthRepository',
            'ensureMemberRecord: existing Members record for $email');
        return;
      }

      final name = email.split('@').first;
      AppLogger.i('AuthRepository',
          'ensureMemberRecord: no Members record for $email, creating one (name=$name)');

      final body = jsonEncode({
        'data': {
          'Member ID': '',
          'Name': name,
          'Email': email,
          'Address': '',
          'City': '',
          'Country': '',
          'Mobile No': '',
          'Postal Code': '',
        },
        'jobTypeId': AppConstants.memberJobTypeId,
      });
      final response = await http.post(
        Uri.parse('${ServerUrls.baseUrl}${ServerUrls.createInstance}'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      AppLogger.i('AuthRepository',
          'ensureMemberRecord: create -> ${response.statusCode}: ${redactedPreview(response.body)}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Create Members instance failed (${response.statusCode}): ${response.body}');
      }
    } catch (e, st) {
      AppLogger.e('AuthRepository', 'ensureMemberRecord($email) failed', e, st);
    }
  }

  Future<void> logout() async {
    AppLogger.i('AuthRepository', 'logout');
    await _sessionStorage.clearSession();
    _apiClient.setAccessToken(null);
    _currentUser = null;
    _activeAgentNames = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Fired by ApiClient the moment any call 401s. The token this app has
  /// been holding onto — since login, possibly hours ago — is no longer
  /// valid server-side, and nothing here tracks that proactively. Previously
  /// this surfaced only as a generic "please sign in again" toast on
  /// whichever screen happened to make the failing call, with no actual
  /// recovery: a currently-open chat screen's own in-memory businessId (see
  /// agent_chat_view.dart) kept being sent alongside the now-invalid token
  /// indefinitely. Clearing the session and returning to login — the same
  /// way a fresh install starts — is the real fix; a bare retry would 401
  /// again with the same token.
  Future<void> _handleSessionExpired() async {
    if (_handlingExpiry || _status == AuthStatus.unauthenticated) return;
    _handlingExpiry = true;
    AppLogger.w('AuthRepository',
        'Session expired (401) — clearing stale session and returning to login');
    try {
      await _sessionStorage.clearSession();
      _apiClient.setAccessToken(null);
      _currentUser = null;
      _activeAgentNames = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Your session has expired. Please sign in again.';
      notifyListeners();
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } finally {
      _handlingExpiry = false;
    }
  }
}
