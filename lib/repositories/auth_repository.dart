import 'package:flutter/foundation.dart';
import '../constants/server_urls.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Session/auth state shared across the app. Wraps [ApiClient] for the
/// login request and [SessionStorage] to persist the result across app
/// restarts — [SplashView] calls [restoreSession] once, before deciding
/// whether to route to login or the chat list.
class AuthRepository extends ChangeNotifier {
  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  AuthRepository(this._apiClient, this._sessionStorage);

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

  /// Fetches /api/v1/module-constants and stores ACTIVE_AGENTS (a
  /// comma-separated agent-name list) for filtering the "New request"
  /// sheet. `moduleConstants` in the response is an array of job-instance
  /// records (the GoSure generic job-type shape) — the constants live in
  /// the first entry's `data` map. Called automatically once authenticated
  /// (see [restoreSession]/[login]) — no UI of its own, failures swallowed.
  Future<void> fetchModuleConstants() async {
    try {
      final json = await _apiClient.get(ServerUrls.moduleConstants) as Map<String, dynamic>;
      final moduleConstants = json['moduleConstants'] as List?;
      final first = (moduleConstants != null && moduleConstants.isNotEmpty) ? moduleConstants[0] as Map<String, dynamic> : null;
      final data = first?['data'] as Map<String, dynamic>?;
      final activeAgents = data?['ACTIVE_AGENTS'] as String?;
      debugPrint('[ModuleConstants] ACTIVE_AGENTS raw string: $activeAgents');
      _activeAgentNames = activeAgents
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      debugPrint('[ModuleConstants] parsed activeAgentNames: $_activeAgentNames');
    } catch (e, st) {
      debugPrint('[ModuleConstants] fetchModuleConstants failed: $e');
      debugPrint('$st');
      // Leave _activeAgentNames as-is (null on first failure) — the sheet
      // falls back to showing every agent rather than none.
    }
  }

  Future<bool> login({required String username, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final json = await _apiClient.post(ServerUrls.login, body: {
        'username': username,
        'password': password,
      }) as Map<String, dynamic>;

      final accessToken = json['accessToken'] as String;
      final token = json['token'] as String;
      final user = User(
        id: json['userId'] as String,
        name: json['Name'] as String,
        username: json['username'] as String,
        roleName: json['accRoleName'] as String,
      );

      await _sessionStorage.saveSession(accessToken: accessToken, token: token, user: user);
      _apiClient.setAccessToken(accessToken);
      _currentUser = user;
      _status = AuthStatus.authenticated;
      await fetchModuleConstants();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Could not reach the server. Check your connection and try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _sessionStorage.clearSession();
    _apiClient.setAccessToken(null);
    _currentUser = null;
    _activeAgentNames = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
