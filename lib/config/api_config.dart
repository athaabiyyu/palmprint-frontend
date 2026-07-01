class ApiConfig {
  // static const String baseUrl = 'https://overtone-reversion-prevent.ngrok-free.dev/api';
  static const String baseUrl =
      'http://172.20.10.2:8000/api';

  // ==================== HEADERS ====================

  /// Header dasar — untuk GET request publik
  static Map<String, String> get baseHeaders => {
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Header untuk request JSON (POST/PUT tanpa auth)
  static Map<String, String> get jsonHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Header untuk GET request dengan auth
  static Map<String, String> authHeaders(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Header untuk POST/PUT JSON dengan auth
  static Map<String, String> authJsonHeaders(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Header untuk MultipartRequest tanpa auth
  static Map<String, String> get multipartHeaders => {
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Header untuk MultipartRequest dengan auth
  static Map<String, String> multipartAuthHeaders(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  // ==================== ENDPOINTS ====================

  // Auth
  static const String register = '$baseUrl/register';
  static const String login = '$baseUrl/login';
  static const String pilihKelas = '$baseUrl/pilih-kelas';
  static const String profil = '$baseUrl/profil';

  static const String riwayatAbsensi = '$baseUrl/mahasiswa/riwayat-absensi';
  static const String uploadSurat = '$baseUrl/mahasiswa/surats';
  static const String daftarSurat = '$baseUrl/mahasiswa/surats';

  // Publik — untuk pilih kelas
  static const String jurusans = '$baseUrl/jurusans';
  static String prodisByJurusan(int jurusanId) =>
      '$baseUrl/jurusans/$jurusanId/prodis';
  static String kelasByProdi(int prodiId) => '$baseUrl/prodis/$prodiId/kelas';

  // Mahasiswa
  static const String jadwalHariIni = '$baseUrl/mahasiswa/jadwal-hari-ini';
  static const String absensi = '$baseUrl/mahasiswa/absensi';
  // ── Tablet (1:N) ──
  static const String sesiAktifTablet = '$baseUrl/tablet/sesi-aktif';
  static const String absensiTablet = '$baseUrl/tablet/absensi'; // ← ubah ini
}
