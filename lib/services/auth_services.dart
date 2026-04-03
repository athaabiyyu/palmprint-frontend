import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../models/mahasiswa.dart';

class AuthService {

  // ==================== REGISTER ====================
  static Future<Map<String, dynamic>> register({
    required String nim,
    required String nama,
    required File foto1,
    required File foto2,
    required File foto3,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.register));

      // Tambah field text
      request.fields['nim']  = nim;
      request.fields['nama'] = nama;

      // Tambah 3 foto
      request.files.add(await http.MultipartFile.fromPath('foto_1', foto1.path));
      request.files.add(await http.MultipartFile.fromPath('foto_2', foto2.path));
      request.files.add(await http.MultipartFile.fromPath('foto_3', foto3.path));

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var body     = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success'   : true,
          'message'   : body['message'],
          'mahasiswa' : Mahasiswa.fromJson(body),
        };
      } else {
        return {
          'success' : false,
          'message' : body['message'] ?? 'Registrasi gagal',
        };
      }
    } catch (e) {
      return {
        'success' : false,
        'message' : 'Koneksi gagal: $e',
      };
    }
  }

  // ==================== LOGIN ====================
  static Future<Map<String, dynamic>> login({
    required String nim,
    required File foto,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.login));

      // Tambah field text
      request.fields['nim'] = nim;

      // Tambah foto
      request.files.add(await http.MultipartFile.fromPath('foto', foto.path));

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var body     = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success'   : true,
          'message'   : body['message'],
          'mahasiswa' : Mahasiswa.fromJson(body),
          'similarity': body['similarity'],
        };
      } else {
        return {
          'success' : false,
          'message' : body['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      return {
        'success' : false,
        'message' : 'Koneksi gagal: $e',
      };
    }
  }
}