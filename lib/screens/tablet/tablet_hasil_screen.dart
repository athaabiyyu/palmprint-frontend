import 'package:flutter/material.dart';
import 'tablet_kamera_screen.dart';

class TabletHasilScreen extends StatelessWidget {
  final bool berhasil;
  final String? nama;
  final String? nim;
  final double similarity;
  final String? pesan;
  final Map<String, dynamic> sesi;

  const TabletHasilScreen({
    super.key,
    required this.berhasil,
    required this.nama,
    required this.nim,
    required this.similarity,
    required this.sesi,
    this.pesan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: berhasil ? Colors.green.shade50 : Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: berhasil ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    berhasil ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  berhasil ? 'Absensi Berhasil!' : 'Tidak Dikenali',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: berhasil ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                if (berhasil && nama != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person, size: 40, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text(nama!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(nim ?? '-', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('Similarity: ${(similarity * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
                if (!berhasil && pesan != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(pesan!, textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700)),
                  ),
                ],
                const SizedBox(height: 32),
                _AutoRedirectButton(sesi: sesi),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoRedirectButton extends StatefulWidget {
  final Map<String, dynamic> sesi;
  const _AutoRedirectButton({required this.sesi});

  @override
  State<_AutoRedirectButton> createState() => _AutoRedirectButtonState();
}

class _AutoRedirectButtonState extends State<_AutoRedirectButton> {
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 3; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdown = i - 1);
    }
    if (mounted) _scanLagi();
  }

  void _scanLagi() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TabletKameraScreen(sesi: widget.sesi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _scanLagi,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Text('Otomatis scan lagi dalam $_countdown detik...',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}