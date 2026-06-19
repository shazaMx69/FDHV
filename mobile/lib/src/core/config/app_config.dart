class AppConfig {
  /// Production backend on Railway.
  static const String _productionUrl = 'https://backend-production-d3846.up.railway.app';

  /// Local backend — use 10.0.2.2 for Android emulator, localhost for iOS simulator.
  /// For a real device on the same Wi-Fi, replace with your machine's local IP:
  ///   e.g. 'http://192.168.1.42:4000'
  static const String _localUrl = 'http://10.0.2.2:4000';

  /// Flip this to false to point at local backend during development.
  static const bool useProduction = true;

  static const String apiBaseUrl = useProduction ? _productionUrl : _localUrl;
}
