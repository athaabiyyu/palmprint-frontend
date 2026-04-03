class ApiConfig {
  // Ganti dengan IP laptop kamu (bukan localhost!)
  // Cek IP laptop: ipconfig → IPv4 Address
  static const String baseUrl = 'http://192.168.1.15:8000/api';

  static const String register = '$baseUrl/register';
  static const String login    = '$baseUrl/login';
}