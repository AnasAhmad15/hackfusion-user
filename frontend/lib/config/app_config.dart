class AppConfig {
  AppConfig._();

  /// The base IP address for the backend. 
  /// Update this ONE value when your backend IP changes.
  static const String backendIp = '192.168.137.1';
  
  /// The full base URL for the backend API.
  static const String baseUrl = 'http://$backendIp:8000';
  
  /// The WebSocket URL for the backend (if needed).
  static const String wsUrl = 'ws://$backendIp:8000';
}
