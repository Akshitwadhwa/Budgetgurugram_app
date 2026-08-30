/// Backend endpoints.
///
/// `baseUrl` is a build-time value so the same binary can point at a laptop, a
/// LAN address, or production without a code change:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// ```
///
/// The default is the Android emulator's alias for the host machine's
/// `localhost`, because that is where the backend runs during development. On
/// a physical device this must be the laptop's LAN IP — `localhost` there means
/// the phone itself, which is the single most common way this looks "broken".
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.10.27.165:8000',
  );

  static const eventsPath = '/v1/events';
  static const healthPath = '/v1/health';

  static String eventDetailPath(String id) => '/v1/events/$id';
  static String askPath(String id) => '/v1/events/$id/ask';

  /// Legacy Vercel endpoint, still the source for nearby places until the
  /// workspace slice moves to this backend.
  static const legacyBaseUrl = 'https://budgetgurugram.vercel.app';
  static const nearbyPath = '/api/nearby-places';
}
