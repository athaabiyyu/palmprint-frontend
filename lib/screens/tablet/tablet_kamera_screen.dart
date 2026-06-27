import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../palm_camera_screen.dart';
import 'tablet_hasil_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

class TabletKameraScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;

  const TabletKameraScreen({super.key, required this.sesi});

  @override
  State<TabletKameraScreen> createState() => _TabletKameraScreenState();
}

class _TabletKameraScreenState extends State<TabletKameraScreen> {
  bool _isProcessing = false;

  Future<void> _mulaiScan() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackbar('Izin kamera diperlukan!');
      return;
    }

    final File? foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => PalmCameraScreen(fotoIndex: 1, token: ''),
      ),
    );

    if (foto == null || !mounted) return;

    setState(() => _isProcessing = true);
    await _kirimAbsensi(foto);
  }

  Future<void> _kirimAbsensi(File foto) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConfig.absensiTablet))
            ..headers.addAll(ApiConfig.baseHeaders)
            ..fields['sesi_absensi_id'] = widget.sesi['id'].toString()
            ..files.add(await http.MultipartFile.fromPath('foto', foto.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        if (!mounted) return;
        _showSnackbar('Server error (${response.statusCode})');
        return;
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TabletHasilScreen(
              berhasil: true,
              nama: data['mahasiswa']?['nama'] ?? '-',
              nim: data['mahasiswa']?['nim'] ?? '-',
              similarity: (data['similarity'] ?? 0.0).toDouble(),
              sesi: widget.sesi,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TabletHasilScreen(
              berhasil: false,
              nama: null,
              nim: null,
              similarity: (data['similarity'] ?? 0.0).toDouble(),
              pesan: data['message'] ?? 'Telapak tangan tidak dikenali.',
              sesi: widget.sesi,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Gagal terhubung ke server: $e');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final jadwal = widget.sesi['jadwal'] ?? {};
    final matkul = jadwal['mata_kuliah'] ?? {};

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(matkul['nama'] ?? 'Absensi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Mengidentifikasi palmprint...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.back_hand, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Siap untuk absensi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    matkul['nama'] ?? '-',
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _mulaiScan,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'Scan Palmprint',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
