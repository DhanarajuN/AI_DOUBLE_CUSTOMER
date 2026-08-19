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

  // Agent display names don't always match the real "Business Category"
  // field value they're meant to represent (e.g. the "Health Care" agent's
  // businesses are actually filed under "Healthcare", no space) — confirmed
  // live: querying by the raw agent name for "Health Care" and "Aidouble
  // Insurance" returned zero businesses even though real ones exist under
  // "Healthcare"/"Health Insurance". Mirrors the portal's own AGENT_CATEGORY
  // map (workbench.ts) so both apps resolve the same agent to the same
  // category. Any agent name not listed here is assumed to already match its
  // category value verbatim (true for "Education" and "Home Services" today).
  // Customer-facing agents are now suffixed "Customer"/"Customer - Voice" to
  // sit alongside their "Business"/"Business - Voice" counterparts, so their
  // display name no longer matches the category verbatim either.
  static const Map<String, String> _agentNameToCategory = {
    'Aidouble Insurance': 'Health Insurance',
    'Health Care': 'Healthcare',
    'Medical Aesthetics Customer': 'Medical Aesthetics',
  };

  static Future<Map<String, String>> _headers() async {
    final token = await SessionStorage().readAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tenant': ServerUrls.tenant,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// The real, structured category label for a Business record — the raw
  /// field carries the reference id alongside the name
  /// ("Medical Aesthetics(6a70ac4f2c869b0bed964af7)"), so prefer the
  /// resolved _ref.label when present. Mirrors the portal's own categoryOf().
  static String _categoryOf(Map<String, dynamic> business) {
    final data = business['data'] as Map<String, dynamic>? ?? const {};
    final ref = data['Business Category_ref'] as Map<String, dynamic>?;
    final label = (ref?['label'] as String?)?.trim();
    if (label != null && label.isNotEmpty) return label;
    final raw = (data['Business Category'] as String? ?? '').trim();
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  /// [category] is matched against the "Business Category" field — the
  /// picked agent's name (e.g. "Healthcare", "Insurance").
  ///
  /// Fetches the whole (small) Business list with no server-side category
  /// filter and matches client-side instead — "contains" on Business
  /// Category (a Selection field) has proven unreliable server-side, the
  /// exact same filter can return real matches one moment and nothing the
  /// next with no data change in between. Confirmed live and is the root
  /// cause of "no businesses" showing here even when real ones exist.
  static Future<List<Map<String, dynamic>>> fetchBusinesses(
      String category) async {
    final resolvedCategory = _agentNameToCategory[category] ?? category;
    final uri =
        Uri.parse('${ServerUrls.baseUrl}${ServerUrls.businessInstances}')
            .replace(queryParameters: {
      'pageNumber': '1',
      'pageSize': '200',
      'filters': jsonEncode(const []),
    });
    final response = await http.get(uri, headers: await _headers());
    AppLogger.i('BusinessService',
        'fetchBusinesses($category -> $resolvedCategory) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to load businesses (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final jobs = json['jobs'];
    if (jobs is! List) return [];
    final wanted = resolvedCategory.trim().toLowerCase();
    return jobs
        .cast<Map<String, dynamic>>()
        .where((business) => _categoryOf(business).toLowerCase() == wanted)
        .toList();
  }
}
