import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:absensi_palmprint_fe/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:math';

class PalmCameraScreen extends StatefulWidget {
  final int fotoIndex;
  final String token;

  const PalmCameraScreen({
    super.key,
    required this.fotoIndex,
    required this.token,
  });

  @override
  State<PalmCameraScreen> createState() => _PalmCameraScreenState();
}

class _PalmCameraScreenState extends State<PalmCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isTakingPhoto = false;

  String? _qualityMessage;
  bool _qualityOk = false;

  // ✅ Diperbesar dari 0.82 → 0.95 agar MediaPipe di server bisa detect landmark
  static const double _roiRatio = 0.95;

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

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
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

  // =====================================================================
  // QUALITY GATE — konsisten dengan server (extractor.py)
  // Semua nilai dikali 255 agar skala sama dengan OpenCV
  // =====================================================================

  double _computeBlurScore(img.Image image) {
    final gray = img.grayscale(image);
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        // ✅ HAPUS * 255 — getLuminance() sudah return 0–255
        final center = img.getLuminance(gray.getPixel(x, y)).toDouble();
        final top = img.getLuminance(gray.getPixel(x, y - 1)).toDouble();
        final bottom = img.getLuminance(gray.getPixel(x, y + 1)).toDouble();
        final left = img.getLuminance(gray.getPixel(x - 1, y)).toDouble();
        final right = img.getLuminance(gray.getPixel(x + 1, y)).toDouble();

        final lap = top + bottom + left + right - 4 * center;
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0;
    final mean = sum / count;
    return (sumSq / count) - (mean * mean);
  }

  double _computeBrightness(img.Image image) {
    final gray = img.grayscale(image);
    double total = 0;
    final pixels = gray.width * gray.height;

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        // ✅ HAPUS * 255
        total += img.getLuminance(gray.getPixel(x, y)).toDouble();
      }
    }
    return total / pixels;
  }

  double _computeContrast(img.Image image) {
    final gray = img.grayscale(image);
    final pixels = gray.width * gray.height;
    double sum = 0;
    double sumSq = 0;

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        // ✅ HAPUS * 255
        final v = img.getLuminance(gray.getPixel(x, y)).toDouble();
        sum += v;
        sumSq += v * v;
      }
    }

    final mean = sum / pixels;
    final variance = (sumSq / pixels) - (mean * mean);
    return variance > 0 ? sqrt(variance.abs()) : 0;
  }

  /// Quality gate — return null kalau lolos, return pesan error kalau gagal.
  /// ✅ Threshold konsisten dengan server (extractor.py check_image_quality)
  String? _checkQuality(img.Image cropped) {
    final resized200 = img.copyResize(cropped, width: 200, height: 200);

    final blurScore = _computeBlurScore(resized200);
    final brightness = _computeBrightness(resized200);
    final contrast = _computeContrast(resized200);

    // Tampilin di console
    debugPrint('==========================================');
    debugPrint('QUALITY GATE DEBUG:');
    debugPrint('blur     = $blurScore');
    debugPrint('bright   = $brightness');
    debugPrint('contrast = $contrast');
    debugPrint('==========================================');
    debugPrint('==========================================');
    debugPrint('fotoIndex    : ${widget.fotoIndex}');
    debugPrint('blur         : $blurScore');
    debugPrint('brightness   : $brightness');
    debugPrint('contrast     : $contrast');
    debugPrint('==========================================');

    if (blurScore < 5) return 'Foto terlalu blur...';
    if (brightness < 20) return 'Foto terlalu gelap...';
    if (brightness > 245) return 'Foto terlalu terang...';
    if (contrast < 5) return 'Detail tidak terlihat...';

    return null;
  }

  // =====================================================================
  // TAKE PHOTO
  // =====================================================================

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPhoto) return;

    setState(() {
      _isTakingPhoto = true;
      _qualityMessage = null;
      _qualityOk = false;
    });

    try {
      final XFile xfile = await _controller!.takePicture();
      final Uint8List rawBytes = await xfile.readAsBytes();

      img.Image? fullImage = img.decodeImage(rawBytes);
      if (fullImage == null) {
        _showError('Gagal decode gambar');
        setState(() => _isTakingPhoto = false);
        return;
      }

      // ── Resize + Crop ──
      img.Image resized = _resizeKeepAspect(fullImage, maxSize: 1440);

      final int imgW = resized.width;
      final int imgH = resized.height;
      final double boxSize = imgW * _roiRatio;
      final double left = (imgW - boxSize) / 2;
      final double top = (imgH - boxSize) / 2 - imgH * 0.08;

      final int cropX = left.clamp(0, imgW - 1).toInt();
      final int cropY = top.clamp(0, imgH - 1).toInt();
      final int cropW = boxSize.clamp(1, imgW - cropX).toInt();
      final int cropH = boxSize.clamp(1, imgH - cropY).toInt();

      img.Image cropped = img.copyCrop(
        resized,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // ── Quality Gate lokal (blur/brightness/contrast) ──
      final String? qualityError = _checkQuality(cropped);
      if (qualityError != null) {
        setState(() {
          _isTakingPhoto = false;
          _qualityMessage = qualityError;
          _qualityOk = false;
        });
        return;
      }

      // ── Simpan sementara untuk validasi ke server ──
      final tempDir = await getTemporaryDirectory();
      final outPath = path.join(
        tempDir.path,
        'palm_${widget.fotoIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));

      // ── Validasi ke server (cek tangan terdeteksi) ──
      setState(() {
        _qualityMessage = null;
        _qualityOk = false;
        // isTakingPhoto tetap true — loading masih jalan
      });

      final String? serverError = await _validateToServer(outFile);

      if (serverError != null) {
        // Tangan tidak terdeteksi / error server
        setState(() {
          _isTakingPhoto = false;
          _qualityMessage = serverError;
          _qualityOk = false;
        });
        return;
      }

      // ── Semua lolos — pop dengan file ──
      setState(() {
        _qualityOk = true;
        _qualityMessage = null;
      });

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.of(context).pop(outFile);
      }
    } catch (e) {
      _showError('Gagal mengambil foto: $e');
      setState(() => _isTakingPhoto = false);
    }
  }

  /// Kirim foto ke FastAPI untuk validasi MediaPipe
  /// Return null kalau lolos, return pesan error kalau gagal
  Future<String?> _validateToServer(File fotoFile) async {
    try {
      final String laravelUrl = widget.token.isEmpty
          ? '${ApiConfig.baseUrl}/validate-palm-guest' // registrasi
          : '${ApiConfig.baseUrl}/validate-palm'; // absensi (sudah login)

      debugPrint('[Validate] Mengirim ke: $laravelUrl');

      final request = http.MultipartRequest('POST', Uri.parse(laravelUrl));

      // ✅ Tambahkan token auth
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.headers['Accept'] = 'application/json';

      request.files.add(
        await http.MultipartFile.fromPath('foto', fotoFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[Validate] Status: ${response.statusCode}');
      debugPrint('[Validate] Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['valid'] == true) {
        return null; // lolos
      } else {
        return data['message'] ?? 'Foto tidak valid. Coba lagi.';
      }
    } on TimeoutException {
      return 'Koneksi timeout. Periksa jaringan.';
    } catch (e) {
      debugPrint('[Validate] ERROR: $e');
      return 'Gagal validasi foto. Periksa koneksi.';
    }
  }

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
      interpolation: img.Interpolation.linear,
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // =====================================================================
  // BUILD
  // =====================================================================

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
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // ── Quality Gate Feedback ──
            if (_isInitialized && (_qualityMessage != null || _qualityOk))
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _qualityMessage != null
                      ? Container(
                          key: const ValueKey('error'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _qualityMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('success'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Foto berhasil diambil!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

            // ── Instruksi ──
            if (_isInitialized)
              Positioned(
                bottom: 100,
                left: 24,
                right: 24,
                child: Column(
                  children: [
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
                bottom: 24,
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
// ROI Overlay
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

    // Overlay gelap di luar kotak
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, overlayPaint);

    // Border kotak
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(rect, borderPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cLen = 24.0;

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

    // Label
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
