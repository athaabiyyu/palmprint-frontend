import 'package:flutter/material.dart';
import '../services/jadwal_service.dart';
import 'upload_surat_screen.dart';

class RiwayatAbsensiScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> mahasiswa;

  const RiwayatAbsensiScreen({
    super.key,
    required this.token,
    required this.mahasiswa,
  });

  @override
  State<RiwayatAbsensiScreen> createState() => _RiwayatAbsensiScreenState();
}

class _RiwayatAbsensiScreenState extends State<RiwayatAbsensiScreen> {
  bool          _isLoading = true;
  List<dynamic> _riwayat   = [];

  @override
  void initState() {
    super.initState();
    _loadRiwayat();
  }

  Future<void> _loadRiwayat() async {
    setState(() => _isLoading = true);
    final result = await JadwalService.riwayatAbsensi(token: widget.token);
    setState(() {
      _isLoading = false;
      if (result['success']) _riwayat = result['data'] ?? [];
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'hadir' : return Colors.green;
      case 'izin'  : return Colors.blue;
      case 'sakit' : return Colors.orange;
      default      : return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'hadir' : return Icons.check_circle;
      case 'izin'  : return Icons.info;
      case 'sakit' : return Icons.local_hospital;
      default      : return Icons.cancel;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'hadir' : return 'Hadir';
      case 'izin'  : return 'Izin';
      case 'sakit' : return 'Sakit';
      default      : return 'Alpha';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title          : const Text('Riwayat Absensi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon     : const Icon(Icons.refresh),
            onPressed: _loadRiwayat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _riwayat.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada riwayat absensi',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRiwayat,
                  child: ListView.builder(
                    padding    : const EdgeInsets.all(16),
                    itemCount  : _riwayat.length,
                    itemBuilder: (context, index) {
                      final item   = _riwayat[index];
                      final status = item['status'] ?? 'alpha';
                      final surat  = item['surat'];

                      return Card(
                        margin   : const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape    : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['matkul'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize  : 15,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color       : _statusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border      : Border.all(color: _statusColor(status)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_statusIcon(status),
                                            size: 14, color: _statusColor(status)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            color     : _statusColor(status),
                                            fontSize  : 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Info
                              Row(children: [
                                const Icon(Icons.calendar_today,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(item['tanggal'] ?? '-',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                                const SizedBox(width: 12),
                                const Icon(Icons.person_outline,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(item['dosen'] ?? '-',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ),
                              ]),

                              // Status surat (jika ada)
                              if (surat != null) ...[
                                const SizedBox(height: 8),
                                _buildSuratStatus(surat),
                              ],

                              // Tombol upload surat (hanya jika alpha & belum ada surat)
                              if (status == 'alpha' && surat == null) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UploadSuratScreen(
                                            token       : widget.token,
                                            sesiId      : item['sesi_id'],
                                            namaMatkul  : item['matkul'] ?? '-',
                                            tanggal     : item['tanggal'] ?? '-',
                                          ),
                                        ),
                                      );
                                      _loadRiwayat(); // refresh setelah upload
                                    },
                                    icon : const Icon(Icons.upload_file,
                                        color: Colors.orange),
                                    label: const Text('Upload Surat',
                                        style: TextStyle(color: Colors.orange)),
                                    style: OutlinedButton.styleFrom(
                                      side : const BorderSide(color: Colors.orange),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildSuratStatus(Map<String, dynamic> surat) {
    Color  color;
    String label;
    IconData icon;

    switch (surat['status']) {
      case 'disetujui':
        color = Colors.green;
        label = 'Surat Disetujui';
        icon  = Icons.check_circle;
        break;
      case 'ditolak':
        color = Colors.red;
        label = 'Surat Ditolak';
        icon  = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        label = 'Surat Pending';
        icon  = Icons.hourglass_empty;
    }

    return Container(
      padding   : const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border      : Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 6),
            Text('(${surat['jenis']})',
                style: TextStyle(color: color, fontSize: 12)),
          ]),
          if (surat['status'] == 'ditolak' && surat['catatan_admin'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Alasan: ${surat['catatan_admin']}',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}