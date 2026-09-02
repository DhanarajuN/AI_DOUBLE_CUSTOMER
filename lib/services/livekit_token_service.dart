import 'api_client.dart';

Future<String> fetchLiveKitToken(
  ApiClient apiClient, {
  required String room,
  required String identity,
  required Map<String, dynamic> metadata,
}) async {
  throw Exception('Voice mode is not connected to a token-minting backend endpoint yet.');
}
