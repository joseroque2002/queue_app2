import 'dart:io';

/// Helper class to check network connectivity
class ConnectivityHelper {
  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if can reach Supabase server
  static Future<bool> canReachSupabase(String supabaseUrl) async {
    try {
      final uri = Uri.parse(supabaseUrl);
      if (uri.host.isEmpty) return false;
      
      final result = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user-friendly error message based on connectivity status
  static Future<String> getConnectivityErrorMessage(String supabaseUrl) async {
    final hasInternet = await hasInternetConnection();
    
    if (!hasInternet) {
      return '📡 No Internet Connection\n\n'
          'Your device is not connected to the internet.\n\n'
          'Please check:\n'
          '• WiFi is turned on and connected\n'
          '• Mobile data is enabled\n'
          '• Airplane mode is off\n\n'
          'Try connecting to a WiFi network or enabling mobile data.';
    }
    
    final canReach = await canReachSupabase(supabaseUrl);
    
    if (!canReach) {
      return '🔌 Cannot Reach Queue System\n\n'
          'Your device is connected to the internet, but cannot reach '
          'the queue management system.\n\n'
          'Possible causes:\n'
          '• The queue system is temporarily down for maintenance\n'
          '• Your network may be blocking the connection\n'
          '• Firewall or security settings may be interfering\n\n'
          'Please try again in a few moments or contact the administrator.';
    }
    
    return 'Connection Error\n\n'
        'An unexpected network error occurred. Please try again.';
  }

  /// Format exception to user-friendly message
  static bool isNetworkException(dynamic exception) {
    final errorString = exception.toString();
    return errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup') ||
        errorString.contains('ClientException') ||
        errorString.contains('HandshakeException') ||
        errorString.contains('TimeoutException') ||
        errorString.contains('NetworkException');
  }
}



