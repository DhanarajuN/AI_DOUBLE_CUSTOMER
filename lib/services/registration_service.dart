import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import 'app_logger.dart';

class RegistrationService {
  RegistrationService._();

  static Future<void> submit(Map<String, dynamic> data) async {
    AppLogger.i('Registration', 'submit request: ${redactJson(data)}');
    final uri = Uri.parse('${ServerUrls.baseUrl}${ServerUrls.createInstancePublic}');
    final response = await http.post(
      uri,
      headers: {
        'X-Tenant': ServerUrls.tenant,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': data, 'jobTypeId': AppConstants.memberJobTypeId}),
    );
    AppLogger.i('Registration', 'submit -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Registration failed (${response.statusCode}): ${response.body}');
    }
  }
}
