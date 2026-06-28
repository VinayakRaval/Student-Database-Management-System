class AppConfig {
  static String _baseUrl = 'http://127.0.0.1:8000/';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    if (!url.endsWith('/')) {
      url = '$url/';
    }
    _baseUrl = url;
  }
}
