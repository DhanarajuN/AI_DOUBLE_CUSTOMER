import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthSession {
  final String accessToken;
  final String token;
  final User user;
  const AuthSession(
      {required this.accessToken, required this.token, required this.user});
}

class SessionStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _nameKey = 'auth_name';
  static const _usernameKey = 'auth_username';
  static const _roleNameKey = 'auth_role_name';

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> readUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> readRoleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleNameKey);
  }

  Future<AuthSession?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    final name = prefs.getString(_nameKey);
    final username = prefs.getString(_usernameKey);
    final roleName = prefs.getString(_roleNameKey);
    if (accessToken == null ||
        token == null ||
        userId == null ||
        name == null ||
        username == null ||
        roleName == null) {
      return null;
    }
    return AuthSession(
      accessToken: accessToken,
      token: token,
      user:
          User(id: userId, name: name, username: username, roleName: roleName),
    );
  }

  Future<void> saveSession(
      {required String accessToken,
      required String token,
      required User user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_nameKey, user.name);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_roleNameKey, user.roleName);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleNameKey);
  }

  // How many messages this device had already seen in a conversation as of the last
  // time it was opened — compared against the server's live message count to show a
  // "N new" badge on the chat list, the same way AI_DOUBLE_BUSINESS does it.
  static const _readCountPrefix = 'gosure_read_count_';

  Future<int> readLastSeenCount(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_readCountPrefix$conversationId') ?? 0;
  }

  Future<void> saveLastSeenCount(String conversationId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_readCountPrefix$conversationId', count);
  }
}
