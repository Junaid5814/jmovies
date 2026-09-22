class AppConfig {
  AppConfig._();

  static const String tmdbAccessToken = String.fromEnvironment(
    'TMDB_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String streamApiBaseUrl = String.fromEnvironment(
    'STREAM_API_BASE_URL',
    defaultValue: '',
  );

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get hasTmdbAccessToken => tmdbAccessToken.trim().isNotEmpty;

  static bool get hasStreamApiBaseUrl => streamApiBaseUrl.trim().isNotEmpty;

  static bool get isProduction =>
      appEnvironment.toLowerCase().trim() == 'production';

  static String get normalizedStreamApiBaseUrl {
    final value = streamApiBaseUrl.trim();

    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }

    return value;
  }

  static void validate() {
    if (!hasTmdbAccessToken) {
      throw StateError(
        'TMDB_ACCESS_TOKEN is missing. '
        'Provide it using --dart-define=TMDB_ACCESS_TOKEN=your_token.',
      );
    }
  }
}
