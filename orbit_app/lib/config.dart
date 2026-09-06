class Config {
  Config._();

  static const String baseUrl = String.fromEnvironment(
    'ORBIT_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get apiBase => '$baseUrl/api/v1';

  static String get wsBase {
    final u = Uri.parse(baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${u.authority}/api/v1';
  }

  static const String googleServerClientId = String.fromEnvironment(
    'ORBIT_GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static bool get hasGoogleClientId => googleServerClientId.isNotEmpty;

  static const bool devAuthEnabled = bool.fromEnvironment(
    'ORBIT_DEV_AUTH',
    defaultValue: false,
  );

  static const double ncrMinLat = 28.20;
  static const double ncrMaxLat = 29.00;
  static const double ncrMinLng = 76.70;
  static const double ncrMaxLng = 77.70;

  static const double ncrCenterLat = 28.6139;
  static const double ncrCenterLng = 77.2090;

  static bool withinNCR(double lat, double lng) =>
      lat >= ncrMinLat &&
      lat <= ncrMaxLat &&
      lng >= ncrMinLng &&
      lng <= ncrMaxLng;
}
