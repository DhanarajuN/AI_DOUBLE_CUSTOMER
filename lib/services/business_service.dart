import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import 'app_logger.dart';
import 'session_storage.dart';

/// Fetches GoSure "Business" JobType instances — each one an individual
/// business a category-level agent (e.g. "Healthcare") represents. Used by
/// the business-picker step between choosing an agent and opening a chat,
/// so every conversation can be tagged with which specific business the
/// customer is talking to (needed for live human handoff).
///
/// Modeled on [ApiClient]'s header pattern (bearer token + tenant) rather
/// than using ApiClient directly, since this needs to run from static
/// helpers without a BuildContext (mirrors LibreChatService's own style).
class BusinessService {
  BusinessService._();

  static Future<Map<String, String>> _headers() async {
    final token = await SessionStorage().readAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tenant': ServerUrls.tenant,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// [category] is matched against the "Business Category" field — the
  /// picked agent's name (e.g. "Healthcare", "Insurance").
  static Future<List<Map<String, dynamic>>> fetchBusinesses(
      String category) async {
    final filters = jsonEncode([
      {
        'fieldName': 'Business Category',
        'condition': 'contains',
        'value': category,
      },
    ]);
    final uri =
        Uri.parse('${ServerUrls.baseUrl}${ServerUrls.businessInstances}')
            .replace(queryParameters: {
      'pageNumber': '1',
      'pageSize': '200',
      'filters': filters,
    });
    final response = await http.get(uri, headers: await _headers());
    AppLogger.i('BusinessService',
        'fetchBusinesses($category) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to load businesses (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final jobs = json['jobs'];
    if (jobs is! List) return [];
    return jobs.cast<Map<String, dynamic>>();
  }
}
