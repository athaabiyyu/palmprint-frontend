class ApiConfig {
  static const String baseUrl = 'http://192.168.1.21:8000/api';

  // Auth
  static const String register      = '$baseUrl/register';
  static const String login         = '$baseUrl/login';
  static const String pilihKelas    = '$baseUrl/pilih-kelas';
  static const String profil        = '$baseUrl/profil';

  // Publik — untuk pilih kelas
  static const String jurusans      = '$baseUrl/jurusans';                    // ← baru
  static String prodisByJurusan(int jurusanId) =>
      '$baseUrl/jurusans/$jurusanId/prodis';                                  // ← baru
  static String kelasByProdi(int prodiId) =>
      '$baseUrl/prodis/$prodiId/kelas';                                       // ← baru

  // Mahasiswa
  static const String jadwalHariIni = '$baseUrl/mahasiswa/jadwal-hari-ini';
  static const String absensi       = '$baseUrl/mahasiswa/absensi';

}