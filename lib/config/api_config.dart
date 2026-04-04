class ApiConfig {
  static const String baseUrl = 'http://192.168.1.15:8000/api';

  static const String register   = '$baseUrl/register';
  static const String login      = '$baseUrl/login';
  static const String daftarKelas = '$baseUrl/daftar-kelas';
  static const String pilihKelas  = '$baseUrl/pilih-kelas';
  static const String profil      = '$baseUrl/profil';
  static const String jadwalHariIni = '$baseUrl/mahasiswa/jadwal-hari-ini';
  static const String absensi     = '$baseUrl/mahasiswa/absensi';
}