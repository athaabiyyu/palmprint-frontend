import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import 'jadwal_screen.dart';

class PilihKelasScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> mahasiswa;

  const PilihKelasScreen({
    super.key,
    required this.token,
    required this.mahasiswa,
  });

  @override
  State<PilihKelasScreen> createState() => _PilihKelasScreenState();
}

class _PilihKelasScreenState extends State<PilihKelasScreen> {
  List<dynamic> _kelasList  = [];
  int?          _selectedId = null;
  bool          _isLoading  = false;
  bool          _loadingKelas = true;

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    final kelas = await AuthService.daftarKelas();
    setState(() {
      _kelasList    = kelas;
      _loadingKelas = false;
    });
  }

  Future<void> _pilihKelas() async {
    if (_selectedId == null) {
      _showSnackbar('Pilih kelas terlebih dahulu!');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.pilihKelas(
      token   : widget.token,
      kelasId : _selectedId!,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JadwalScreen(
            token     : widget.token,
            mahasiswa : widget.mahasiswa,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title          : const Text('Pilih Kelas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // tidak bisa back
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.class_, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Pilih Kelas Anda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilihan ini hanya bisa dilakukan sekali dan tidak dapat diubah sendiri.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // List Kelas
            _loadingKelas
                ? const Center(child: CircularProgressIndicator())
                : _kelasList.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada kelas tersedia.\nHubungi admin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _kelasList.length,
                          itemBuilder: (context, index) {
                            final kelas = _kelasList[index];
                            final isSelected = _selectedId == kelas['id'];

                            return GestureDetector(
                              onTap: () => setState(() => _selectedId = kelas['id']),
                              child: Container(
                                margin  : const EdgeInsets.only(bottom: 12),
                                padding : const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border      : Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color       : isSelected ? Colors.blue.shade50 : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                                      color: isSelected ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          kelas['nama'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.blue : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          kelas['semester']?['nama'] ?? '',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

            const SizedBox(height: 16),

            // Tombol Konfirmasi
            SizedBox(
              width : double.infinity,
              height: 50,
              child : ElevatedButton(
                onPressed: _isLoading ? null : _pilihKelas,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Konfirmasi Kelas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}