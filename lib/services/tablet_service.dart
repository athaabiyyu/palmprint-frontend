import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class TabletService {
  // ==================== SESI AKTIF KELAS ====================
  // Dipanggil saat kiosk pertama nyala / refresh, untuk tahu
  // kelas & jadwal mana yang sedang berlangsung di tablet ini.
  static Future<Map<String, dynamic>> sesiAktif() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.sesiAktifTablet),
        headers: ApiConfig.baseHeaders,
      );

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Response kosong dari server'};
      }

      final body = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? body,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Tidak ada sesi aktif',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ==================== ABSENSI VIA TABLET ====================
  // Kirim foto telapak tangan hasil capture dari PalmCameraScreen
  // untuk dicocokkan & dicatat sebagai kehadiran.
  static Future<Map<String, dynamic>> absensi({
    required File fotoTelapak,
    int? sesiId, // sesuaikan kalau backend butuh sesi_id / jadwal_id
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.absensiTablet),
      );

      request.headers.addAll(ApiConfig.multipartHeaders);
      if (sesiId != null) {
        request.fields['sesi_id'] = sesiId.toString();
      }
      request.files.add(
        await http.MultipartFile.fromPath('foto', fotoTelapak.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Response kosong dari server'};
      }

      final body = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'],
          'data': body['data'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Absensi gagal — tangan tidak dikenali',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }
}