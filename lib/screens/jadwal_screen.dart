import 'package:flutter/material.dart';
import '../services/jadwal_service.dart';
import 'absensi_screen.dart';

class JadwalScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> mahasiswa;

  const JadwalScreen({
    super.key,
    required this.token,
    required this.mahasiswa,
  });

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  bool           _isLoading = true;
  List<dynamic>  _jadwals   = [];
  String         _kelas     = '';
  String         _hari      = '';

  @override
  void initState() {
    super.initState();
    _loadJadwal();
  }

  Future<void> _loadJadwal() async {
    setState(() => _isLoading = true);

    final result = await JadwalService.jadwalHariIni(token: widget.token);

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _jadwals = result['data']['data'] ?? [];
        _kelas   = result['data']['kelas'] ?? '';
        _hari    = result['data']['hari']  ?? '';
      }
    });
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title          : const Text('Jadwal Hari Ini'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon    : const Icon(Icons.refresh),
            onPressed: _loadJadwal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadJadwal,
              child: CustomScrollView(
                slivers: [
                  // Header info
                  SliverToBoxAdapter(
                    child: Container(
                      color  : Colors.blue,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child  : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, ${widget.mahasiswa['nama']}!',
                            style: const TextStyle(
                              color     : Colors.white,
                              fontSize  : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelas $_kelas • ${_capitalize(_hari)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // List jadwal
                  _jadwals.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Tidak ada jadwal hari ini',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final jadwal    = _jadwals[index];
                                final sesiAktif = jadwal['sesi_aktif'];
                                final sudahAbsen = jadwal['sudah_absen'] ?? false;

                                return _JadwalCard(
                                  jadwal     : jadwal,
                                  sesiAktif  : sesiAktif,
                                  sudahAbsen : sudahAbsen,
                                  onAbsen    : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AbsensiScreen(
                                          token        : widget.token,
                                          mahasiswa    : widget.mahasiswa,
                                          sesiAbsensiId: sesiAktif['id'],
                                          namaMatkul   : jadwal['mata_kuliah']['nama'],
                                        ),
                                      ),
                                    );
                                    _loadJadwal(); // refresh setelah absen
                                  },
                                );
                              },
                              childCount: _jadwals.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}

class _JadwalCard extends StatelessWidget {
  final Map<String, dynamic> jadwal;
  final dynamic              sesiAktif;
  final bool                 sudahAbsen;
  final VoidCallback         onAbsen;

  const _JadwalCard({
    required this.jadwal,
    required this.sesiAktif,
    required this.sudahAbsen,
    required this.onAbsen,
  });

  @override
  Widget build(BuildContext context) {
    final matkul = jadwal['mata_kuliah'];
    final dosen  = jadwal['dosen'];

    Color  statusColor;
    String statusText;
    bool   bisaAbsen = false;

    if (sudahAbsen) {
      statusColor = Colors.green;
      statusText  = 'Sudah Absen';
    } else if (sesiAktif != null) {
      statusColor = Colors.orange;
      statusText  = 'Sesi Aktif';
      bisaAbsen   = true;
    } else {
      statusColor = Colors.grey;
      statusText  = 'Belum Dibuka';
    }

    return Card(
      margin       : const EdgeInsets.only(bottom: 12),
      elevation    : 2,
      shape        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    matkul['nama'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color       : statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border      : Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(dosen['nama'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${jadwal['jam_mulai']} - ${jadwal['jam_selesai']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            if (bisaAbsen) ...[
              const SizedBox(height: 12),
              SizedBox(
                width : double.infinity,
                child : ElevatedButton.icon(
                  onPressed: onAbsen,
                  icon : const Icon(Icons.fingerprint),
                  label: const Text('Absen Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (sudahAbsen) ...[
              const SizedBox(height: 12),
              Container(
                width     : double.infinity,
                padding   : const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color       : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border      : Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Kehadiran Tercatat', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}