import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'register_screen.dart';
import 'pilih_kelas_screen.dart';
import 'jadwal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nimController      = TextEditingController();
  final _passwordController = TextEditingController();
  bool  _isLoading          = false;
  bool  _obscurePassword    = true;

  Future<void> _login() async {
    if (_nimController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackbar('NIM dan password harus diisi!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      nim      : _nimController.text.trim(),
      password : _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      // Simpan token & data mahasiswa
      final token             = result['token'];
      final mahasiswa         = result['mahasiswa'];
      final sudahPilihKelas   = result['sudah_pilih_kelas'];

      if (!mounted) return;

      if (!sudahPilihKelas) {
        // Belum pilih kelas → ke PilihKelasScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PilihKelasScreen(
              token     : token,
              mahasiswa : mahasiswa,
            ),
          ),
        );
      } else {
        // Sudah pilih kelas → ke JadwalScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => JadwalScreen(
              token     : token,
              mahasiswa : mahasiswa,
            ),
          ),
        );
      }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Icon(Icons.back_hand, size: 80, color: Colors.blue.shade300),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Sistem Absensi Palmprint',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 40),

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

              // Password
              const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller    : _passwordController,
                obscureText   : _obscurePassword,
                decoration    : InputDecoration(
                  hintText    : 'Masukkan password',
                  border      : OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon  : const Icon(Icons.lock),
                  suffixIcon  : IconButton(
                    icon   : Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Login
              SizedBox(
                width : double.infinity,
                height: 50,
                child : ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

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
      ),
    );
  }
}