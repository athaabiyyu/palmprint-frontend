class ApiConfig {
  static const String baseUrl = 'http://192.168.1.6:8000/api';

  // Auth
  static const String register = '$baseUrl/register';
  static const String login = '$baseUrl/login';
  static const String pilihKelas = '$baseUrl/pilih-kelas';
  static const String profil = '$baseUrl/profil';

  static const String riwayatAbsensi = '$baseUrl/mahasiswa/riwayat-absensi';
  static const String uploadSurat = '$baseUrl/mahasiswa/surats';
  static const String daftarSurat = '$baseUrl/mahasiswa/surats';

  // Publik — untuk pilih kelas
  static const String jurusans = '$baseUrl/jurusans'; // ← baru
  static String prodisByJurusan(int jurusanId) =>
      '$baseUrl/jurusans/$jurusanId/prodis'; // ← baru
  static String kelasByProdi(int prodiId) =>
      '$baseUrl/prodis/$prodiId/kelas'; // ← baru

  // Mahasiswa
  static const String jadwalHariIni = '$baseUrl/mahasiswa/jadwal-hari-ini';
  static const String absensi = '$baseUrl/mahasiswa/absensi';
}
