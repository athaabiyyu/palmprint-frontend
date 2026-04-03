import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_services.dart';
import 'register_screen.dart';
import 'absensi_screen.dart'; // ← tambahkan import ini

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nimController = TextEditingController();
  File? _foto;
  bool  _isLoading = false;

  // ==================== AMBIL FOTO ====================
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

  // ==================== LOGIN ====================
  Future<void> _login() async {
    if (_nimController.text.isEmpty) {
      _showSnackbar('NIM harus diisi!');
      return;
    }
    if (_foto == null) {
      _showSnackbar('Foto telapak tangan harus diambil!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      nim : _nimController.text.trim(),
      foto: _foto!,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      _showSnackbar('Login berhasil! Selamat datang.');

      // Navigasi ke halaman absensi, hapus semua route sebelumnya
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AbsensiScreen(nim: _nimController.text.trim()),
        ),
        (route) => false,
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

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title          : const Text('Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Logo/Icon
            Center(
              child: Icon(
                Icons.back_hand,
                size : 80,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Sistem Absensi Palmprint',
                style: TextStyle(
                  fontSize  : 18,
                  fontWeight: FontWeight.bold,
                  color     : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // NIM
            const Text('NIM', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller  : _nimController,
              keyboardType: TextInputType.number,
              decoration  : InputDecoration(
                hintText  : 'Masukkan NIM',
                border    : OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),

            // Foto telapak tangan
            const Text(
              'Foto Telapak Tangan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Center(
              child: GestureDetector(
                onTap: _ambilFoto,
                child: Container(
                  width : 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border      : Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    color       : Colors.blue.shade50,
                  ),
                  child: _foto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_foto!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.blue, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Tap untuk ambil foto\ntelapak tangan kiri',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Login
            SizedBox(
              width : double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
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
                        'Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Link ke Register
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Belum punya akun? Daftar di sini'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}