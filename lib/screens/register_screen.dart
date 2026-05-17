import 'dart:io';
import 'package:absensi_palmprint_fe/screens/pilih_kelas_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_services.dart';
import 'palm_camera_screen.dart'; // ← screen kamera baru

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nimController      = TextEditingController();
  final _namaController     = TextEditingController();
  final _passwordController = TextEditingController();
  bool  _obscurePassword    = true;

  File? _foto1;
  File? _foto2;
  File? _foto3;

  bool _isLoading = false;

  // ==================== BUKA KAMERA DENGAN PANDUAN ROI ====================
  Future<void> _ambilFoto(int index) async {
    // Minta izin kamera
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackbar('Izin kamera diperlukan!');
      return;
    }

    // Buka PalmCameraScreen — hasil crop ROI dikembalikan sebagai File
    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => PalmCameraScreen(fotoIndex: index),
      ),
    );

    if (result != null) {
      setState(() {
        if (index == 1) _foto1 = result;
        if (index == 2) _foto2 = result;
        if (index == 3) _foto3 = result;
      });
      _showSnackbar('Foto $index berhasil diambil ✓');
    }
  }

  // ==================== REGISTER ====================
  Future<void> _register() async {
    if (_nimController.text.isEmpty ||
        _namaController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackbar('NIM, nama, dan password harus diisi!');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showSnackbar('Password minimal 6 karakter!');
      return;
    }
    if (_foto1 == null || _foto2 == null || _foto3 == null) {
      _showSnackbar('Semua foto telapak tangan harus diambil!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      nim      : _nimController.text.trim(),
      nama     : _namaController.text.trim(),
      password : _passwordController.text,
      foto1    : _foto1!,
      foto2    : _foto2!,
      foto3    : _foto3!,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PilihKelasScreen(
            token     : result['token'],
            mahasiswa : result['mahasiswa'],
          ),
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

  // ==================== WIDGET FOTO ====================
  Widget _fotoBox(int index, File? foto) {
    final bool sudahAmbil = foto != null;
    return GestureDetector(
      onTap: () => _ambilFoto(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width : 100,
        height: 100,
        decoration: BoxDecoration(
          border      : Border.all(
            color: sudahAmbil ? Colors.green : Colors.blue,
            width: sudahAmbil ? 2.5 : 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color       : sudahAmbil ? Colors.green.shade50 : Colors.blue.shade50,
        ),
        child: foto != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(foto, fit: BoxFit.cover, width: 100, height: 100),
                  ),
                  // Checkmark di pojok kanan atas
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
                  // Label "Tap ulang" di bawah
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Tap ulang',
                        style: TextStyle(color: Colors.white70, fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.blue, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    'Foto $index',
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
    final allFotoAmbil = _foto1 != null && _foto2 != null && _foto3 != null;

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
              controller  : _nimController,
              keyboardType: TextInputType.number,
              decoration  : InputDecoration(
                hintText  : 'Masukkan NIM',
                border    : OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge),
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
            const SizedBox(height: 16),

            // Password
            const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller  : _passwordController,
              obscureText : _obscurePassword,
              decoration  : InputDecoration(
                hintText  : 'Minimal 6 karakter',
                border    : OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Foto telapak tangan
            Row(
              children: [
                const Text(
                  'Foto Telapak Tangan (3 foto)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (allFotoAmbil)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Ambil 3 foto telapak tangan kiri.\nPanduan kotak akan muncul di kamera.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),

            // Progress bar foto
            LinearProgressIndicator(
              value: [_foto1, _foto2, _foto3].where((f) => f != null).length / 3,
              backgroundColor: Colors.blue.shade50,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
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
              width : double.infinity,
              height: 50,
              child : ElevatedButton(
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