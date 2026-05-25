class ApiConstants {
  static const String baseUrl = 'http://localhost:8000';

  // Auth
  static const String loginUrl   = '$baseUrl/api/auth/login';
  static const String refreshUrl = '$baseUrl/api/auth/refresh';
  static const String logoutUrl  = '$baseUrl/api/auth/logout';

  // Users
  static const String usersUrl   = '$baseUrl/api/users';

  // Forêts
  static const String forestsUrl        = '$baseUrl/api/v1/forests';
  static const String forestsGeoJsonUrl = '$baseUrl/api/v1/forests/geojson';

  static const Duration requestTimeout = Duration(seconds: 20);
}

// Alias utilisé par AlertRepository et les providers superviseur
class ApiConfig {
  static const String baseUrl = ApiConstants.baseUrl;
}