import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/jadwal_service.dart';

class AbsensiScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> mahasiswa;
  final int    sesiAbsensiId;
  final String namaMatkul;

  const AbsensiScreen({
    super.key,
    required this.token,
    required this.mahasiswa,
    required this.sesiAbsensiId,
    required this.namaMatkul,
  });

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  File? _foto;
  bool  _isLoading  = false;
  bool  _berhasil   = false;
  String _pesanHasil = '';

  Future<void> _ambilFoto() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackbar('Izin kamera diperlukan!');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source      : ImageSource.camera,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() => _foto = File(picked.path));
    }
  }

  Future<void> _absensi() async {
    if (_foto == null) {
      _showSnackbar('Ambil foto telapak tangan terlebih dahulu!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await JadwalService.absensi(
      token        : widget.token,
      sesiAbsensiId: widget.sesiAbsensiId,
      foto         : _foto!,
    );

    setState(() {
      _isLoading  = false;
      _berhasil   = result['success'];
      _pesanHasil = result['message'];
    });

    if (result['success']) {
      // Tampilkan dialog sukses
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Absensi Berhasil!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.namaMatkul,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Similarity: ${(result['similarity'] * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // tutup dialog
                Navigator.pop(context); // kembali ke jadwal
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      _showSnackbar(result['message']);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title          : const Text('Absensi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Info matkul
            Container(
              width     : double.infinity,
              padding   : const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color       : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border      : Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.book, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    widget.namaMatkul,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Scan telapak tangan kiri untuk absensi',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Area foto
            GestureDetector(
              onTap: _isLoading ? null : _ambilFoto,
              child: Container(
                width : 220,
                height: 220,
                decoration: BoxDecoration(
                  border      : Border.all(
                    color: _foto != null ? Colors.blue : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color       : Colors.grey.shade50,
                ),
                child: _foto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(_foto!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.back_hand, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Tap untuk scan\ntelapak tangan kiri',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Tombol ambil ulang
            if (_foto != null)
              TextButton.icon(
                onPressed: _ambilFoto,
                icon : const Icon(Icons.refresh),
                label: const Text('Ambil Ulang'),
              ),

            const SizedBox(height: 32),

            // Tombol Absensi
            SizedBox(
              width : double.infinity,
              height: 50,
              child : ElevatedButton.icon(
                onPressed: _isLoading ? null : _absensi,
                icon : _isLoading
                    ? const SizedBox(
                        width : 20,
                        height: 20,
                        child : CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(
                  _isLoading ? 'Memproses...' : 'Absensi Sekarang',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}