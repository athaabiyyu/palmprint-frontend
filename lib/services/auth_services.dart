import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class AuthService {

  // ==================== REGISTER ====================
  static Future<Map<String, dynamic>> register({
    required String nim,
    required String nama,
    required String password,
    required File foto1,
    required File foto2,
    required File foto3,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.register));

      request.fields['nim']      = nim;
      request.fields['nama']     = nama;
      request.fields['password'] = password;
      request.headers['Accept']  = 'application/json';

      request.files.add(await http.MultipartFile.fromPath('foto_1', foto1.path));
      request.files.add(await http.MultipartFile.fromPath('foto_2', foto2.path));
      request.files.add(await http.MultipartFile.fromPath('foto_3', foto3.path));

      var streamedResponse = await request.send();
      var response         = await http.Response.fromStream(streamedResponse);

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Response kosong dari server'};
      }

      var body = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success'           : true,
          'message'           : body['message'],
          'token'             : body['token'],
          'sudah_pilih_kelas' : body['sudah_pilih_kelas'],
          'mahasiswa' : body['mahasiswa'] ?? body['data'],
        };
      } else {
        return {
          'success' : false,
          'message' : body['message'] ?? 'Registrasi gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ==================== LOGIN ====================
  static Future<Map<String, dynamic>> login({
    required String nim,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type' : 'application/json',
          'Accept'       : 'application/json',
        },
        body: json.encode({'nim': nim, 'password': password}),
      );

      final body = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success'           : true,
          'message'           : body['message'],
          'token'             : body['token'],
          'sudah_pilih_kelas' : body['sudah_pilih_kelas'],
          'mahasiswa'         : body['data'],
        };
      } else {
        return {
          'success' : false,
          'message' : body['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ==================== DAFTAR JURUSAN ====================
  static Future<List<dynamic>> daftarJurusan() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.jurusans),
        headers: {'Accept': 'application/json'},
      );
      return json.decode(response.body);
    } catch (e) {
      return [];
    }
  }

  // ==================== DAFTAR PRODI BY JURUSAN ====================
  static Future<List<dynamic>> daftarProdi(int jurusanId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.prodisByJurusan(jurusanId)),
        headers: {'Accept': 'application/json'},
      );
      return json.decode(response.body);
    } catch (e) {
      return [];
    }
  }

  // ==================== DAFTAR KELAS BY PRODI ====================
  static Future<List<dynamic>> daftarKelas(int prodiId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.kelasByProdi(prodiId)),
        headers: {'Accept': 'application/json'},
      );
      return json.decode(response.body);
    } catch (e) {
      return [];
    }
  }

  // ==================== PILIH KELAS ====================
  static Future<Map<String, dynamic>> pilihKelas({
    required String token,
    required int kelasId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.pilihKelas),
        headers: {
          'Content-Type'  : 'application/json',
          'Accept'        : 'application/json',
          'Authorization' : 'Bearer $token',
        },
        body: json.encode({'kelas_id': kelasId}),
      );

      final body = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message']};
      } else {
        return {'success': false, 'message': body['message'] ?? 'Gagal memilih kelas'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }
}