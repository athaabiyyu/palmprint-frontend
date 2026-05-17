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
  // ── Step control ──
  int _step = 0; // 0: jurusan, 1: prodi, 2: kelas

  // ── Data ──
  List<dynamic> _jurusanList = [];
  List<dynamic> _prodiList   = [];
  List<dynamic> _kelasList   = [];

  // ── Selected ──
  Map<String, dynamic>? _selectedJurusan;
  Map<String, dynamic>? _selectedProdi;
  int?                  _selectedKelasId;

  // ── Loading ──
  bool _loadingJurusan = true;
  bool _loadingProdi   = false;
  bool _loadingKelas   = false;
  bool _isSubmitting   = false;

  @override
  void initState() {
    super.initState();
    _loadJurusan();
  }

  // ── Load Jurusan ──
  Future<void> _loadJurusan() async {
    final data = await AuthService.daftarJurusan();
    setState(() {
      _jurusanList    = data;
      _loadingJurusan = false;
    });
  }

  // ── Load Prodi by Jurusan ──
  Future<void> _loadProdi(int jurusanId) async {
    setState(() => _loadingProdi = true);
    final data = await AuthService.daftarProdi(jurusanId);
    setState(() {
      _prodiList   = data;
      _loadingProdi = false;
    });
  }

  // ── Load Kelas by Prodi ──
  Future<void> _loadKelas(int prodiId) async {
    setState(() => _loadingKelas = true);
    final data = await AuthService.daftarKelas(prodiId);
    setState(() {
      _kelasList   = data;
      _loadingKelas = false;
    });
  }

  // ── Pilih Jurusan ──
  void _onPilihJurusan(Map<String, dynamic> jurusan) {
    setState(() {
      _selectedJurusan  = jurusan;
      _selectedProdi    = null;
      _selectedKelasId  = null;
      _prodiList        = [];
      _kelasList        = [];
      _step             = 1;
    });
    _loadProdi(jurusan['id']);
  }

  // ── Pilih Prodi ──
  void _onPilihProdi(Map<String, dynamic> prodi) {
    setState(() {
      _selectedProdi   = prodi;
      _selectedKelasId = null;
      _kelasList       = [];
      _step            = 2;
    });
    _loadKelas(prodi['id']);
  }

  // ── Submit Pilih Kelas ──
  Future<void> _submit() async {
    if (_selectedKelasId == null) {
      _showSnackbar('Pilih kelas terlebih dahulu!');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await AuthService.pilihKelas(
      token   : widget.token,
      kelasId : _selectedKelasId!,
    );

    setState(() => _isSubmitting = false);

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

  // ── Back antar step ──
  void _backStep() {
    setState(() {
      if (_step == 2) {
        _step            = 1;
        _selectedKelasId = null;
        _kelasList       = [];
      } else if (_step == 1) {
        _step           = 0;
        _selectedProdi  = null;
        _prodiList      = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_stepTitle()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: _step > 0
            ? IconButton(
                icon    : const Icon(Icons.arrow_back),
                onPressed: _backStep,
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Progress Indicator ──
          _buildProgressBar(),

          // ── Content ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),

          // ── Tombol Konfirmasi (hanya di step kelas) ──
          if (_step == 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width : double.infinity,
                height: 50,
                child : ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Konfirmasi Kelas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Progress Bar ──
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: List.generate(3, (i) {
          final labels = ['Jurusan', 'Prodi', 'Kelas'];
          final isActive   = i == _step;
          final isDone     = i < _step;

          return Expanded(
            child: Row(
              children: [
                // Circle
                Container(
                  width : 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive ? Colors.blue : Colors.grey.shade300,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color     : isActive ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize  : 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                // Label
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize  : 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color     : isActive ? Colors.blue : Colors.grey,
                  ),
                ),
                // Line connector
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color : i < _step ? Colors.blue : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step Title ──
  String _stepTitle() {
    switch (_step) {
      case 0: return 'Pilih Jurusan';
      case 1: return 'Pilih Program Studi';
      case 2: return 'Pilih Kelas';
      default: return 'Pilih Kelas';
    }
  }

  // ── Step Content ──
  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStepJurusan();
      case 1: return _buildStepProdi();
      case 2: return _buildStepKelas();
      default: return const SizedBox();
    }
  }

  // ── Step 0: Jurusan ──
  Widget _buildStepJurusan() {
    if (_loadingJurusan) return const Center(child: CircularProgressIndicator());

    if (_jurusanList.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada jurusan tersedia.\nHubungi admin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Pilih jurusan kamu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilihan ini menentukan prodi dan kelas yang tersedia.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _jurusanList.length,
            itemBuilder: (context, index) {
              final jurusan    = _jurusanList[index];
              final isSelected = _selectedJurusan?['id'] == jurusan['id'];
              return _buildCard(
                title    : jurusan['nama'],
                subtitle : jurusan['kode'],
                isSelected: isSelected,
                onTap    : () => _onPilihJurusan(jurusan),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 1: Prodi ──
  Widget _buildStepProdi() {
    if (_loadingProdi) return const Center(child: CircularProgressIndicator());

    if (_prodiList.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada program studi tersedia.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Jurusan: ${_selectedJurusan?['nama'] ?? ''}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih program studi kamu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _prodiList.length,
            itemBuilder: (context, index) {
              final prodi      = _prodiList[index];
              final isSelected = _selectedProdi?['id'] == prodi['id'];
              return _buildCard(
                title    : prodi['nama'],
                subtitle : prodi['kode'],
                isSelected: isSelected,
                onTap    : () => _onPilihProdi(prodi),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 2: Kelas ──
  Widget _buildStepKelas() {
    if (_loadingKelas) return const Center(child: CircularProgressIndicator());

    if (_kelasList.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada kelas tersedia untuk prodi ini.\nHubungi admin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '${_selectedJurusan?['nama']} › ${_selectedProdi?['nama']}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih kelas kamu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilihan ini hanya bisa dilakukan sekali.',
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _kelasList.length,
            itemBuilder: (context, index) {
              final kelas      = _kelasList[index];
              final isSelected = _selectedKelasId == kelas['id'];
              return _buildCard(
                title    : kelas['nama'],
                subtitle : kelas['semester']?['nama'] ?? '',
                isSelected: isSelected,
                onTap    : () => setState(() => _selectedKelasId = kelas['id']),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Card Item ──
  Widget _buildCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.shade50 : Colors.white,
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
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue : Colors.black,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
            const Spacer(),
            if (!isSelected)
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}