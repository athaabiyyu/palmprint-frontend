import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nimController  = TextEditingController();
  final _namaController = TextEditingController();

  File? _foto1;
  File? _foto2;
  File? _foto3;

  bool _isLoading = false;

  // ==================== AMBIL FOTO ====================
  Future<void> _ambilFoto(int index) async {
    // Minta izin kamera
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackbar('Izin kamera diperlukan!');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source     : ImageSource.camera,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        if (index == 1) _foto1 = File(picked.path);
        if (index == 2) _foto2 = File(picked.path);
        if (index == 3) _foto3 = File(picked.path);
      });
    }
  }

  // ==================== REGISTER ====================
  Future<void> _register() async {
    // Validasi input
    if (_nimController.text.isEmpty || _namaController.text.isEmpty) {
      _showSnackbar('NIM dan nama harus diisi!');
      return;
    }
    if (_foto1 == null || _foto2 == null || _foto3 == null) {
      _showSnackbar('Semua foto telapak tangan harus diambil!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      nim  : _nimController.text.trim(),
      nama : _namaController.text.trim(),
      foto1: _foto1!,
      foto2: _foto2!,
      foto3: _foto3!,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      _showSnackbar('Registrasi berhasil! Silakan login.');
      Navigator.pop(context);
    } else {
      _showSnackbar(result['message']);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==================== WIDGET FOTO ====================
  Widget _fotoBox(int index, File? foto) {
    return GestureDetector(
      onTap: () => _ambilFoto(index),
      child: Container(
        width : 100,
        height: 100,
        decoration: BoxDecoration(
          border      : Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(12),
          color       : Colors.blue.shade50,
        ),
        child: foto != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(foto, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.blue, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    'Foto ${index}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NIM
            const Text('NIM', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nimController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText    : 'Masukkan NIM',
                border      : OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon  : const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),

            // Nama
            const Text('Nama', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _namaController,
              decoration: InputDecoration(
                hintText  : 'Masukkan nama lengkap',
                border    : OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),

            // Foto telapak tangan
            const Text(
              'Foto Telapak Tangan (3 foto)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ambil 3 foto telapak tangan kiri dari sudut berbeda',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // 3 foto box
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _fotoBox(1, _foto1),
                _fotoBox(2, _foto2),
                _fotoBox(3, _foto3),
              ],
            ),
            const SizedBox(height: 32),

            // Tombol Register
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Daftar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}