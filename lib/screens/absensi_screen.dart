import 'package:flutter/material.dart';

class AbsensiScreen extends StatelessWidget {
  final String nim;

  const AbsensiScreen({super.key, required this.nim});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const _LoginPlaceholder()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.back_hand, size: 80, color: Colors.blue.shade200),
            const SizedBox(height: 16),
            Text(
              'Selamat datang, $nim',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Halaman Absensi',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder — ganti dengan LoginScreen import yang sebenarnya
class _LoginPlaceholder extends StatelessWidget {
  const _LoginPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Login Screen')),
      );
}