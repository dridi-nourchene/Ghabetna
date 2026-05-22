
class ApiConstants {
  static const baseUrl = 'http://10.253.135.105:8000';

  // ── Auth ──────────────────────────────────────────────
  static const loginUrl   = '$baseUrl/api/auth/login';
  static const refreshUrl = '$baseUrl/api/auth/refresh';
  static const logoutUrl  = '$baseUrl/api/auth/logout';

  // ── Alerts ────────────────────────────────────────────
  static const alertsUrl     = '$baseUrl/api/alerts/';
  static const myAlertsUrl   = '$baseUrl/api/alerts/mine';

  // ── Forests ───────────────────────────────────────────
  static const forestsUrl    = '$baseUrl/api/forests/';

  // ─────────────────────────────────────────────────────
  static const requestTimeout = Duration(seconds: 90);
}