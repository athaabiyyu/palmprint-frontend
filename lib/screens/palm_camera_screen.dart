import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Screen kamera khusus dengan overlay panduan ROI telapak tangan.
/// Crop gambar sesuai kotak panduan SEBELUM dikirim ke backend.
/// Menyimpan debug crop ke folder lokal untuk debugging.
///
/// Cara pakai di register_screen.dart:
///   final file = await Navigator.push<File>(
///     context,
///     MaterialPageRoute(builder: (_) => PalmCameraScreen(fotoIndex: index)),
///   );
///   if (file != null) setState(() => _foto1 = file);

class PalmCameraScreen extends StatefulWidget {
  final int fotoIndex;

  const PalmCameraScreen({super.key, required this.fotoIndex});

  @override
  State<PalmCameraScreen> createState() => _PalmCameraScreenState();
}

class _PalmCameraScreenState extends State<PalmCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isTakingPhoto = false;

  // GANTI dengan — frame lebih kecil, user harus dekatkan tangan
  static const double _roiRatio = 0.82;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('Tidak ada kamera tersedia');
        return;
      }

      // Pakai kamera belakang
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh, // high = ~1280x720 atau lebih
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Gagal inisialisasi kamera: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPhoto) return;

    setState(() => _isTakingPhoto = true);

    try {
      final XFile xfile = await _controller!.takePicture();
      final Uint8List rawBytes = await xfile.readAsBytes();

      img.Image? fullImage = img.decodeImage(rawBytes);
      if (fullImage == null) {
        _showError('Gagal decode gambar');
        setState(() => _isTakingPhoto = false);
        return;
      }

      // ── Resize dulu ke maxSize agar tidak terlalu berat ──
      img.Image resized = _resizeKeepAspect(fullImage, maxSize: 1440);

      // ── Crop sesuai kotak overlay ROI ──
      // Posisi kotak overlay sama persis dengan _ROIPainter:
      //   boxSize = width * _roiRatio
      //   left    = (width - boxSize) / 2
      //   top     = (height - boxSize) / 2 - height * 0.08
      //
      // Koordinat ini dalam piksel layar (screen space).
      // Kita perlu konversi ke piksel gambar (image space).

      final int imgW = resized.width;
      final int imgH = resized.height;

      // Hitung posisi kotak dalam image space
      // (proporsi sama dengan screen space karena aspect ratio dijaga)
      final double boxSize = imgW * _roiRatio;
      final double left = (imgW - boxSize) / 2;
      final double top = (imgH - boxSize) / 2 - imgH * 0.08;

      // Clamp agar tidak keluar batas gambar
      final int cropX = left.clamp(0, imgW - 1).toInt();
      final int cropY = top.clamp(0, imgH - 1).toInt();
      final int cropW = boxSize.clamp(1, imgW - cropX).toInt();
      final int cropH = boxSize.clamp(1, imgH - cropY).toInt();

      // Crop gambar sesuai kotak overlay
      img.Image cropped = img.copyCrop(
        resized,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // ── Simpan ke temp file ──
      final tempDir = await getTemporaryDirectory();
      final outPath = path.join(
        tempDir.path,
        'palm_full_${widget.fotoIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));

      // ── Debug: simpan salinan ──
      await _saveDebugImages(cropped, outPath);

      if (mounted) {
        Navigator.of(context).pop(outFile);
      }
    } catch (e) {
      _showError('Gagal mengambil foto: $e');
      setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _saveDebugImages(img.Image resized, String outPath) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final debugDir = Directory(path.join(docDir.path, 'palm_debug'));
      if (!await debugDir.exists()) await debugDir.create(recursive: true);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final idx = widget.fotoIndex;

      // Simpan gambar yang akan dikirim ke Python (sama persis)
      final debugFile = File(path.join(debugDir.path, 'foto${idx}_${ts}.jpg'));
      await debugFile.writeAsBytes(img.encodeJpg(resized, quality: 88));

      // Buat gambar annotated: gambar + info ukuran di pojok
      img.Image annotated = img.Image.from(resized);

      // Tulis info ukuran di pojok kiri atas (pakai warna putih)
      img.drawString(
        annotated,
        '${resized.width}x${resized.height}px | foto $idx',
        font: img.arial14,
        x: 10,
        y: 10,
        color: img.ColorRgb8(255, 255, 0),
      );

      final annotatedFile = File(
        path.join(debugDir.path, 'foto${idx}_${ts}_annotated.jpg'),
      );
      await annotatedFile.writeAsBytes(img.encodeJpg(annotated, quality: 85));

      debugPrint('==========================================');
      debugPrint('DEBUG PALM - Foto $idx tersimpan:');
      debugPrint('  Ukuran    : ${resized.width} x ${resized.height} px');
      debugPrint('  Dikirim ke: $outPath');
      debugPrint('  Debug copy: ${debugFile.path}');
      debugPrint('  Annotated : ${annotatedFile.path}');
      debugPrint('  Semua file: ${debugDir.path}');
      debugPrint('==========================================');

      // Tampilkan snackbar info path (hanya di debug mode)
      assert(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Debug: ${resized.width}x${resized.height}px\n'
                'Saved: ${debugDir.path}',
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
        return true;
      }());
    } catch (e) {
      debugPrint('Gagal simpan debug image: $e');
    }
  }

  /// Resize gambar agar sisi terpanjang = maxSize, proporsi tetap
  img.Image _resizeKeepAspect(img.Image src, {required int maxSize}) {
    final w = src.width;
    final h = src.height;
    if (w <= maxSize && h <= maxSize) return src;

    final landscape = w >= h;
    final newW = landscape ? maxSize : (maxSize * w / h).round();
    final newH = landscape ? (maxSize * h / w).round() : maxSize;

    return img.copyResize(
      src,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Helper: gambar kotak outline di Image
  void _drawRect(
    img.Image image,
    int x1,
    int y1,
    int x2,
    int y2,
    img.Color color, {
    int thickness = 2,
  }) {
    for (int t = 0; t < thickness; t++) {
      // Top & bottom
      for (int x = x1; x <= x2; x++) {
        if (y1 + t < image.height && x < image.width)
          image.setPixel(x, y1 + t, color);
        if (y2 - t >= 0 && x < image.width) image.setPixel(x, y2 - t, color);
      }
      // Left & right
      for (int y = y1; y <= y2; y++) {
        if (x1 + t < image.width && y < image.height)
          image.setPixel(x1 + t, y, color);
        if (x2 - t >= 0 && y < image.height) image.setPixel(x2 - t, y, color);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Camera Preview ──
            if (_isInitialized && _controller != null)
              Positioned.fill(child: CameraPreview(_controller!))
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // ── Overlay gelap di luar kotak ROI ──
            if (_isInitialized)
              Positioned.fill(child: _ROIOverlay(roiRatio: _roiRatio)),

            // ── Header ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Foto ${widget.fotoIndex} — Telapak Tangan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // balance back button
                  ],
                ),
              ),
            ),

            // ── Instruksi di bawah kotak ──
            if (_isInitialized)
              Positioned(
                bottom: 130,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.back_hand,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Letakkan telapak tangan di dalam kotak',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Jaga jarak ±20 cm • Telapak menghadap kamera • Jari renggang',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // ── Tombol Ambil Foto ──
            if (_isInitialized)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _isTakingPhoto ? null : _takePhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isTakingPhoto ? 64 : 72,
                      height: _isTakingPhoto ? 64 : 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isTakingPhoto ? Colors.grey : Colors.white,
                        border: Border.all(color: Colors.white54, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isTakingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.black87,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Custom Painter: overlay gelap di luar ROI + kotak panduan
// =====================================================================

class _ROIOverlay extends StatelessWidget {
  final double roiRatio;
  const _ROIOverlay({required this.roiRatio});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ROIPainter(roiRatio: roiRatio),
      child: const SizedBox.expand(),
    );
  }
}

class _ROIPainter extends CustomPainter {
  final double roiRatio;
  const _ROIPainter({required this.roiRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final boxSize = size.width * roiRatio;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2 - size.height * 0.08;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);

    // ── Overlay gelap di luar kotak ──
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // ── Border kotak ROI ──
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(rect, borderPaint);

    // ── Corner brackets (L-shape di 4 sudut) ──
    final cornerPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cLen = 24.0; // panjang tiap bracket

    // Top-left
    canvas.drawLine(Offset(left, top + cLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cLen, top), cornerPaint);
    // Top-right
    canvas.drawLine(
      Offset(left + boxSize - cLen, top),
      Offset(left + boxSize, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + boxSize, top),
      Offset(left + boxSize, top + cLen),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(left, top + boxSize - cLen),
      Offset(left, top + boxSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + boxSize),
      Offset(left + cLen, top + boxSize),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(left + boxSize - cLen, top + boxSize),
      Offset(left + boxSize, top + boxSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + boxSize, top + boxSize - cLen),
      Offset(left + boxSize, top + boxSize),
      cornerPaint,
    );

    // ── Label "ROI" di pojok kiri atas ──
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'AREA SCAN',
        style: TextStyle(
          color: Colors.lightBlueAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(left + 8, top + 8));
  }

  @override
  bool shouldRepaint(covariant _ROIPainter old) => old.roiRatio != roiRatio;
}
