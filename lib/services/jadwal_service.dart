import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class JadwalService {

  // ==================== JADWAL HARI INI ====================
  static Future<Map<String, dynamic>> jadwalHariIni({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.jadwalHariIni),
        headers: {
          'Accept'        : 'application/json',
          'Authorization' : 'Bearer $token',
        },
      );

      final body = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': body};
      } else {
        return {'success': false, 'message': body['message'] ?? 'Gagal memuat jadwal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ==================== ABSENSI PALMPRINT ====================
  static Future<Map<String, dynamic>> absensi({
    required String token,
    required int sesiAbsensiId,
    required File foto,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.absensi),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept']        = 'application/json';
      request.fields['sesi_absensi_id'] = sesiAbsensiId.toString();
      request.files.add(await http.MultipartFile.fromPath('foto', foto.path));

      var streamedResponse = await request.send();
      var response         = await http.Response.fromStream(streamedResponse);
      var body             = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success'   : true,
          'message'   : body['message'],
          'similarity': body['similarity'],
        };
      } else {
        return {
          'success' : false,
          'message' : body['message'] ?? 'Absensi gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }
}