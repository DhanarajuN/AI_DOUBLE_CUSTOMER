/// Backend base URL + endpoint paths, kept in one place instead of scattered
/// as string literals through repositories. Point [baseUrl] at the real
/// backend when it's ready, and pass these paths straight into
/// ApiClient.get/post/put from an Api*Repository implementation — see
/// services/api_client.dart and the "Swapping static data for a real API"
/// section of README.md.
class ServerUrls {
  ServerUrls._();

  static const String baseUrl = 'https://$tenant.dev.gosure.ai';

  // Sent as the X-Tenant header on every request.
  static const String tenant = 'amc';

  // Auth
  static const String login = '/api/v1/users/login';

  // Professionals
  static const String pros = '/pros';
  static String proById(String id) => '/pros/$id';

  // Category intake scripts / metadata / booking slots
  static const String scripts = '/scripts';
  static String scriptByCategory(String category) => '/scripts/$category';
  static const String categoryMeta = '/category-meta';
  static const String slots = '/slots';

  // Conversations
  static const String convos = '/convos';
  static String convoById(String id) => '/convos/$id';

  // Bookings
  static const String bookings = '/bookings';
}
