import 'package:flutter/material.dart';
import '../../services/jadwal_service.dart';

class UploadSuratScreen extends StatefulWidget {
  final String token;
  final int    sesiId;
  final String namaMatkul;
  final String tanggal;

  const UploadSuratScreen({
    super.key,
    required this.token,
    required this.sesiId,
    required this.namaMatkul,
    required this.tanggal,
  });

  @override
  State<UploadSuratScreen> createState() => _UploadSuratScreenState();
}

class _UploadSuratScreenState extends State<UploadSuratScreen> {
  String _jenis       = 'izin';
  bool   _isLoading   = false;

  final _linkController       = TextEditingController();
  final _keteranganController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final link = _linkController.text.trim();

    if (link.isEmpty) {
      _showSnackbar('Link Google Drive wajib diisi!');
      return;
    }

    if (!link.startsWith('http')) {
      _showSnackbar('Link tidak valid! Harus berupa URL.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await JadwalService.uploadSurat(
      token        : widget.token,
      sesiAbsensiId: widget.sesiId,
      jenis        : _jenis,
      linkDrive    : link,
      keterangan   : _keteranganController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      showDialog(
        context          : context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 70),
              const SizedBox(height: 16),
              const Text('Surat Berhasil Diajukan!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Surat kamu sedang menunggu review admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // tutup dialog
                Navigator.pop(context); // kembali ke riwayat
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

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title          : const Text('Upload Surat'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Info pertemuan
            Container(
              width  : double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color       : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border      : Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pengajuan Surat untuk:',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(widget.namaMatkul,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 13, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(widget.tanggal,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 13)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Jenis surat
            const Text('Jenis Surat',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _jenis = 'izin'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color : _jenis == 'izin'
                          ? Colors.blue.shade50 : Colors.grey.shade100,
                      border: Border.all(
                        color: _jenis == 'izin'
                            ? Colors.blue : Colors.grey.shade300,
                        width: _jenis == 'izin' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Icon(Icons.info,
                          color: _jenis == 'izin'
                              ? Colors.blue : Colors.grey),
                      const SizedBox(height: 4),
                      Text('Izin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _jenis == 'izin'
                                ? Colors.blue : Colors.grey,
                          )),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _jenis = 'sakit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color : _jenis == 'sakit'
                          ? Colors.red.shade50 : Colors.grey.shade100,
                      border: Border.all(
                        color: _jenis == 'sakit'
                            ? Colors.red : Colors.grey.shade300,
                        width: _jenis == 'sakit' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Icon(Icons.local_hospital,
                          color: _jenis == 'sakit'
                              ? Colors.red : Colors.grey),
                      const SizedBox(height: 4),
                      Text('Sakit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _jenis == 'sakit'
                                ? Colors.red : Colors.grey,
                          )),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Link Drive
            const Text('Link Google Drive',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller : _linkController,
              decoration : InputDecoration(
                hintText     : 'https://drive.google.com/...',
                prefixIcon   : const Icon(Icons.link),
                border       : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide  : const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan file dapat diakses oleh siapapun yang memiliki link.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Keterangan
            const Text('Keterangan (opsional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller : _keteranganController,
              maxLines   : 3,
              decoration : InputDecoration(
                hintText     : 'Jelaskan alasan ketidakhadiran...',
                border       : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide  : const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Submit
            SizedBox(
              width : double.infinity,
              height: 50,
              child : ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon : _isLoading
                    ? const SizedBox(
                        width : 20, height: 20,
                        child : CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(
                  _isLoading ? 'Mengajukan...' : 'Ajukan Surat',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}