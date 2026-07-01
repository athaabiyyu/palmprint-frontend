import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_services.dart';
import '../../screens/shared/palm_camera_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ==================== CONTROLLER ====================
  final _nimController = TextEditingController();
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // ==================== FOTO ====================
  File? _foto1;
  File? _foto2;
  File? _foto3;

  // ==================== DROPDOWN: JURUSAN / PRODI / KELAS ====================
  List<dynamic> _jurusanList = [];
  List<dynamic> _prodiList = [];
  List<dynamic> _kelasList = [];

  Map<String, dynamic>? _selectedJurusan;
  Map<String, dynamic>? _selectedProdi;
  Map<String, dynamic>? _selectedKelas;

  bool _loadingJurusan = true;
  bool _loadingProdi = false;
  bool _loadingKelas = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJurusan();
  }

  @override
  void dispose() {
    _nimController.dispose();
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==================== LOAD DROPDOWN DATA ====================
  Future<void> _loadJurusan() async {
    final data = await AuthService.daftarJurusan();
    if (!mounted) return;
    setState(() {
      _jurusanList = data;
      _loadingJurusan = false;
    });
  }

  Future<void> _onPilihJurusan(Map<String, dynamic>? jurusan) async {
    if (jurusan == null) return;
    setState(() {
      _selectedJurusan = jurusan;
      _selectedProdi = null;
      _selectedKelas = null;
      _prodiList = [];
      _kelasList = [];
      _loadingProdi = true;
    });

    final data = await AuthService.daftarProdi(jurusan['id']);
    if (!mounted) return;
    setState(() {
      _prodiList = data;
      _loadingProdi = false;
    });
  }

  Future<void> _onPilihProdi(Map<String, dynamic>? prodi) async {
    if (prodi == null) return;
    setState(() {
      _selectedProdi = prodi;
      _selectedKelas = null;
      _kelasList = [];
      _loadingKelas = true;
    });

    final data = await AuthService.daftarKelas(prodi['id']);
    if (!mounted) return;
    setState(() {
      _kelasList = data;
      _loadingKelas = false;
    });
  }

  // ==================== KAMERA ====================
  Future<void> _ambilFoto(int index) async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showSnackbar('Izin kamera diperlukan!');
      return;
    }

    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => PalmCameraScreen(fotoIndex: index, token: ''),
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

  // ==================== SUBMIT REGISTER ====================
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
    if (_selectedJurusan == null || _selectedProdi == null || _selectedKelas == null) {
      _showSnackbar('Jurusan, prodi, dan kelas harus dipilih!');
      return;
    }
    if (_foto1 == null || _foto2 == null || _foto3 == null) {
      _showSnackbar('Semua foto telapak tangan harus diambil!');
      return;
    }

    setState(() => _isLoading = true);

    // ── Step 1: Register akun ──
    final registerResult = await AuthService.register(
      nim: _nimController.text.trim(),
      nama: _namaController.text.trim(),
      password: _passwordController.text,
      foto1: _foto1!,
      foto2: _foto2!,
      foto3: _foto3!,
    );

    if (!registerResult['success']) {
      setState(() => _isLoading = false);
      _showSnackbar(registerResult['message']);
      return;
    }

    final String token = registerResult['token'];

    // ── Step 2: Pilih kelas (pakai token dari step 1) ──
    final pilihKelasResult = await AuthService.pilihKelas(
      token: token,
      kelasId: _selectedKelas!['id'],
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (pilihKelasResult['success']) {
      _showSnackbar('Registrasi berhasil! Silakan login.');
      Navigator.pop(context); // balik ke LoginScreen
    } else {
      // Akun sudah terbuat tapi pilih kelas gagal — tetap arahkan ke login,
      // mahasiswa bisa pilih kelas lagi nanti (kalau ada alur fallback di backend).
      _showSnackbar(
        'Akun dibuat, tapi gagal memilih kelas: ${pilihKelasResult['message']}',
      );
      Navigator.pop(context);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== WIDGET FOTO ====================
  Widget _fotoBox(int index, File? foto) {
    final bool sudahAmbil = foto != null;
    return GestureDetector(
      onTap: () => _ambilFoto(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: sudahAmbil ? Colors.green : Colors.blue,
            width: sudahAmbil ? 2.5 : 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: sudahAmbil ? Colors.green.shade50 : Colors.blue.shade50,
        ),
        child: foto != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(foto, fit: BoxFit.cover, width: 100, height: 100),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
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
                  Text('Foto $index', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                ],
              ),
      ),
    );
  }

  // ==================== WIDGET DROPDOWN ====================
  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    required bool loading,
    required bool enabled,
    String hint = 'Pilih',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(icon),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))))
              .toList(),
          onChanged: enabled && !loading ? onChanged : null,
        ),
        const SizedBox(height: 16),
      ],
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
              controller: _nimController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Masukkan NIM',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                hintText: 'Masukkan nama lengkap',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Minimal 6 karakter',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Dropdown Jurusan / Prodi / Kelas ──
            const Text(
              'Data Akademik',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),

            _buildDropdown<Map<String, dynamic>>(
              label: 'Jurusan',
              icon: Icons.account_balance,
              value: _selectedJurusan,
              items: _jurusanList.cast<Map<String, dynamic>>(),
              itemLabel: (j) => j['nama'] ?? '',
              onChanged: _onPilihJurusan,
              loading: _loadingJurusan,
              enabled: true,
              hint: 'Pilih jurusan',
            ),

            _buildDropdown<Map<String, dynamic>>(
              label: 'Program Studi',
              icon: Icons.school,
              value: _selectedProdi,
              items: _prodiList.cast<Map<String, dynamic>>(),
              itemLabel: (p) => p['nama'] ?? '',
              onChanged: _onPilihProdi,
              loading: _loadingProdi,
              enabled: _selectedJurusan != null,
              hint: _selectedJurusan == null ? 'Pilih jurusan dulu' : 'Pilih prodi',
            ),

            _buildDropdown<Map<String, dynamic>>(
              label: 'Kelas',
              icon: Icons.groups,
              value: _selectedKelas,
              items: _kelasList.cast<Map<String, dynamic>>(),
              itemLabel: (k) => k['nama'] ?? '',
              onChanged: (k) => setState(() => _selectedKelas = k),
              loading: _loadingKelas,
              enabled: _selectedProdi != null,
              hint: _selectedProdi == null ? 'Pilih prodi dulu' : 'Pilih kelas',
            ),

            const SizedBox(height: 8),

            // Foto telapak tangan
            Row(
              children: [
                const Text(
                  'Foto Telapak Tangan (3 foto)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (allFotoAmbil) const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Ambil 3 foto telapak tangan kiri.\nPanduan kotak akan muncul di kamera.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: [_foto1, _foto2, _foto3].where((f) => f != null).length / 3,
              backgroundColor: Colors.blue.shade50,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 16),

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Daftar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}