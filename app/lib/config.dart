/// Defaults are shared by splash and offline preview; backend config wins online.
abstract final class AppConfig {
  static const name = 'PMG AppI';
  static const school = 'Philipp Melanchthon Gymnasium Meine';
  static const year = 2027;
  static const tagline = 'Unser Jahrgang. Unser Ball.';
  static const apiBaseUrl = String.fromEnvironment(
    'APPI_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
