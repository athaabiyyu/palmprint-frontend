class Mahasiswa {
  final int    id;
  final String nim;
  final String nama;
  final String token;

  Mahasiswa({
    required this.id,
    required this.nim,
    required this.nama,
    required this.token,
  });

  factory Mahasiswa.fromJson(Map<String, dynamic> json) {
    return Mahasiswa(
      id    : json['data']['id'],
      nim   : json['data']['nim'],
      nama  : json['data']['nama'],
      token : json['token'],
    );
  }
}