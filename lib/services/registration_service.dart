import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import 'app_logger.dart';

/// Submits the member/professional registration form to GoSure's generic
/// job-instance API (`POST /api/v1/public/create-instance`) — a public,
/// no-auth endpoint keyed by [_jobTypeId] with a freeform `data` map whose
/// keys are the job type's configured field names.
///
/// TODO(backend-confirm): [_jobTypeId] is a placeholder — replace with the
/// real id for the registration job type once confirmed; every submit will
/// fail (likely 400/404) until then. The `data` keys below (`Name`,
/// `Email`, ...) are also assumed to match the form's visible labels
/// exactly — confirm against the actual job type schema.
class RegistrationService {
  RegistrationService._();

  static const _jobTypeId = 'TODO_REGISTRATION_JOB_TYPE_ID';

  static Future<void> submit(Map<String, dynamic> data) async {
    AppLogger.i('Registration', 'submit request: ${redactJson(data)}');
    final response = await http.post(
      Uri.parse('${ServerUrls.baseUrl}${ServerUrls.createInstance}'),
      headers: {
        'X-Tenant': ServerUrls.tenant,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': data, 'jobTypeId': _jobTypeId}),
    );
    AppLogger.i('Registration', 'submit -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Registration failed (${response.statusCode}): ${response.body}');
    }
  }
}
