/// Build-time configuration passed with `--dart-define` (SPEC §3.3).
///
/// - `API_BASE_URL`: defaults to the Android emulator's host alias. For a USB phone use
///   `http://localhost:3000` together with `adb reverse tcp:3000 tcp:3000`.
/// - `DEMO_USER_ID`: the seeded demo user (`DEMO_USER_ID` in the backend `.env`).
class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

  static const String demoUserId = String.fromEnvironment(
    'DEMO_USER_ID',
    defaultValue: '00000000-0000-4000-8000-000000000001',
  );

  /// Resolves an API-relative asset URL (e.g. `/static/assets/x.png`) against [apiBaseUrl] (SPEC §3.4).
  static String resolveAssetUrl(String url, {String base = apiBaseUrl}) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) return url;
    return Uri.parse(base).resolve(url).toString();
  }
}
