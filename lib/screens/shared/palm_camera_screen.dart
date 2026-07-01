import 'dart:io';
import 'dart:ui' as ui;
import 'roi_crop_flutter.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

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

  HandLandmarkerPlugin? _handLandmarker;
  bool _isDetecting = false;
  List<Hand>? _detectedHands;
  bool _handDetected = false;

  final List<double> _palmHHistory = [];

  final List<List<List<double>>> _landmarkHistory = [];
  static const int _landmarkWindowSize = 8;

  static const int _palmHWindowSize = 5;

  String? _qualityMessage;
  bool _qualityOk = false;
  String _palmGuideMessage = 'Arahkan telapak tangan ke kamera...';

  DateTime? _handDetectedSince;
  static const Duration _autoCaptureDelay = Duration(seconds: 2);
  int _autoCountdown = 2;

  static const double _roiRatio = 0.95;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHandLandmarker();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _safeStopStream();
    _controller?.dispose();
    _handLandmarker?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _safeStopStream();
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _safeStopStream() {
    try {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          _controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
    } catch (e) {
      debugPrint('[Camera] stopImageStream ignored: $e');
    }
  }

  Future<void> _safeStartStream() async {
    try {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          !_controller!.value.isStreamingImages) {
        await _controller!.startImageStream(_onCameraImage);
      }
    } catch (e) {
      debugPrint('[Camera] startImageStream ignored: $e');
    }
  }

  void _initHandLandmarker() {
    try {
      _handLandmarker = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.6,
        delegate: HandLandmarkerDelegate.GPU,
      );
      debugPrint('[HandLandmarker] ✓ Initialized (GPU)');
    } catch (e) {
      debugPrint('[HandLandmarker] ✗ GPU Error: $e');
      try {
        _handLandmarker = HandLandmarkerPlugin.create(
          numHands: 1,
          minHandDetectionConfidence: 0.5,
          delegate: HandLandmarkerDelegate.CPU,
        );
        debugPrint('[HandLandmarker] ✓ Initialized (CPU fallback)');
      } catch (e2) {
        debugPrint('[HandLandmarker] ✗ CPU fallback error: $e2');
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('Tidak ada kamera tersedia');
        return;
      }

      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high, // ← turun dari veryHigh, decode lebih cepat
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _safeStartStream();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Gagal inisialisasi kamera: $e');
    }
  }

  DateTime _lastDetection = DateTime.now();
  DateTime _lastSetState = DateTime.now();

  Future<void> _onCameraImage(CameraImage cameraImage) async {
    if (_isDetecting || _handLandmarker == null) return;

    final now = DateTime.now();
    if (now.difference(_lastDetection).inMilliseconds < 100) return;
    _lastDetection = now;

    _isDetecting = true;
    try {
      final List<Hand> hands = await Future.microtask(
        () => _handLandmarker!.detect(
          cameraImage,
          _controller!.description.sensorOrientation,
        ),
      );

      if (mounted &&
          DateTime.now().difference(_lastSetState).inMilliseconds > 100) {
        _lastSetState = DateTime.now();
        setState(() {
          _detectedHands = hands;
          if (hands.isNotEmpty) {
            // Simpan landmark ke history
            final lmXY = hands.first.landmarks
                .map((lm) => [lm.x, lm.y])
                .toList();
            _landmarkHistory.add(lmXY);
            if (_landmarkHistory.length > _landmarkWindowSize) {
              _landmarkHistory.removeAt(0);
            }
            debugPrint(
              '[Smooth] landmark pushed, size=${_landmarkHistory.length}',
            );

            final issue = _checkPalmGuide(hands.first);
            _handDetected = (issue == null);

            if (_handDetected) {
              _handDetectedSince ??= DateTime.now();
              final held = DateTime.now().difference(_handDetectedSince!);
              final remaining = (_autoCaptureDelay - held).inSeconds.clamp(
                0,
                2,
              );
              _autoCountdown = remaining;

              if (held >= _autoCaptureDelay && !_isTakingPhoto) {
                _palmGuideMessage = 'Mengambil foto...';
                Future.microtask(() => _takePhoto());
              } else {
                _palmGuideMessage = remaining > 0
                    ? 'Tahan posisi... $remaining detik'
                    : 'Mengambil foto...';
              }
            } else {
              _handDetectedSince = null;
              _autoCountdown = 2;
              _palmGuideMessage =
                  issue ?? 'Arahkan telapak tangan ke kamera...';
            }
          } else {
            if (hands.isEmpty) {
              _handDetected = false;
              _handDetectedSince = null;
              _autoCountdown = 2;
              _palmGuideMessage = 'Arahkan telapak tangan ke kamera...';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[Stream] Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  List<List<double>> _getSmoothedLandmarks() {
    if (_landmarkHistory.isEmpty) return [];

    final n = _landmarkHistory.length;
    final numPoints = _landmarkHistory.first.length;

    // Frame terbaru dapat bobot lebih besar
    final weights = List.generate(n, (i) => (i + 1).toDouble());
    final totalWeight = weights.reduce((a, b) => a + b);

    return List.generate(numPoints, (i) {
      double avgX = 0, avgY = 0;
      for (int f = 0; f < n; f++) {
        avgX += _landmarkHistory[f][i][0] * weights[f];
        avgY += _landmarkHistory[f][i][1] * weights[f];
      }
      return [avgX / totalWeight, avgY / totalWeight];
    });
  }

  String? _checkPalmGuide(Hand hand) {
    // Ambil sensor orientation dari controller
    final so = _controller!.description.sensorOrientation;

    // Helper transform — sama persis dengan yang di crop
    Offset transformLm(double x, double y) {
      Offset result;
      switch (so) {
        case 90:
          result = Offset(1.0 - y, x);
          // Flip untuk SO=90 front camera
          return Offset(1.0 - result.dx, result.dy);
        case 270:
          result = Offset(y, 1.0 - x);
          // SO=270 front camera: tidak perlu flip
          return result;
        case 180:
          result = Offset(1.0 - x, 1.0 - y);
          return Offset(1.0 - result.dx, result.dy);
        default:
          result = Offset(x, y);
          return Offset(1.0 - result.dx, result.dy);
      }
    }

    final wrist = transformLm(hand.landmarks[0].x, hand.landmarks[0].y);
    final indexMcp = transformLm(hand.landmarks[5].x, hand.landmarks[5].y);
    final middleMcp = transformLm(hand.landmarks[9].x, hand.landmarks[9].y);
    final pinkyMcp = transformLm(hand.landmarks[17].x, hand.landmarks[17].y);
    final indexTip = transformLm(hand.landmarks[8].x, hand.landmarks[8].y);
    final middleTip = transformLm(hand.landmarks[12].x, hand.landmarks[12].y);

    // ── Spread check ──
    final mcpXs = [indexMcp.dx, middleMcp.dx, pinkyMcp.dx];
    final mcpYs = [indexMcp.dy, middleMcp.dy, pinkyMcp.dy];
    final spreadX = mcpXs.reduce(max) - mcpXs.reduce(min);
    final spreadY = mcpYs.reduce(max) - mcpYs.reduce(min);
    final spread = max(spreadX, spreadY);
    if (spread < 0.15) return 'Buka jari lebih lebar';

    // ── Telapak menghadap kamera ──
    final avgMcpY = (indexMcp.dy + middleMcp.dy + pinkyMcp.dy) / 3;
    if (wrist.dy < avgMcpY) return 'Balikkan telapak menghadap kamera';

    // ── Jari melipat (dengan toleransi) ──
    const fingerBendThreshold = 0.06;
    final indexBent = (indexTip.dy - indexMcp.dy) > fingerBendThreshold;
    final middleBent = (middleTip.dy - middleMcp.dy) > fingerBendThreshold;
    if (indexBent && middleBent) return 'Luruskan jari-jari tangan';

    // ── Angle check (sudah pakai koordinat transformed) ──
    final handAngle =
        atan2(middleMcp.dx - wrist.dx, -(middleMcp.dy - wrist.dy)) * 180 / pi;

    debugPrint('[PalmGuide] handAngle=${handAngle.toStringAsFixed(1)}° so=$so');

    if (handAngle.abs() > 12) {
      final arah = handAngle > 0 ? 'ke kanan' : 'ke kiri';
      final deg = handAngle.abs().toStringAsFixed(0);
      return 'Miringkan tangan $arah ($deg°)';
    }

    // ── Jarak (palmWidth sudah di koordinat normalized 0-1) ──
    final vx = pinkyMcp.dx - indexMcp.dx;
    final vy = pinkyMcp.dy - indexMcp.dy;
    final palmWidth = sqrt(vx * vx + vy * vy);

    if (palmWidth >= 0.05) {
      _palmHHistory.add(palmWidth);
      if (_palmHHistory.length > _palmHWindowSize) _palmHHistory.removeAt(0);
    }

    final smoothedWidth = _palmHHistory.isNotEmpty
        ? _palmHHistory.reduce((a, b) => a + b) / _palmHHistory.length
        : palmWidth;

    debugPrint(
      '[PalmGuide] palmWidth=$smoothedWidth spread=$spread angle=$handAngle',
    );

    if (smoothedWidth > 0.40) return 'Terlalu dekat — mundurkan tangan';
    if (smoothedWidth < 0.35) return 'Terlalu jauh — dekatkan tangan ke kamera';

    return null;
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPhoto) return;
    if (!_handDetected) return;

    setState(() {
      _isTakingPhoto = true;
      _qualityMessage = null;
      _qualityOk = false;
    });

    try {
      _safeStopStream();
      await Future.delayed(const Duration(milliseconds: 100));

      final XFile xfile = await _controller!.takePicture();
      final Uint8List rawBytes = await xfile.readAsBytes();

      if (_detectedHands == null || _detectedHands!.isEmpty) {
        await _safeStartStream();
        setState(() {
          _isTakingPhoto = false;
          _qualityMessage =
              'Tangan tidak terdeteksi.\nArahkan telapak ke kamera.';
          _qualityOk = false;
        });
        return;
      }

      final List<List<double>> lmXY = _getSmoothedLandmarks();
      if (lmXY.isEmpty || _landmarkHistory.length < 3) {
        await _safeStartStream();
        setState(() {
          _isTakingPhoto = false;
          _qualityMessage = 'Stabilkan posisi tangan dulu.';
        });
        return;
      }
      debugPrint(
        '[Camera] sensorOrientation=${_controller!.description.sensorOrientation}',
      );
      debugPrint(
        '[Camera] lensDirection=${_controller!.description.lensDirection}',
      );
      final args = _PhotoProcessArgs(
        rawBytes: rawBytes,
        landmarkXY: lmXY,
        sensorOrientation: _controller!.description.sensorOrientation,
      );

      final result = await compute(_processPhotoInIsolate, args);

      if (result.errorMessage != null) {
        await _safeStartStream();
        setState(() {
          _isTakingPhoto = false;
          _qualityMessage = result.errorMessage;
          _qualityOk = false;
        });
        return;
      }

      final Uint8List finalBytes = base64Decode(result.filePath!);
      final tempDir = await getTemporaryDirectory();
      final outPath = path.join(
        tempDir.path,
        'palm_${widget.fotoIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final outFile = File(outPath);
      await outFile.writeAsBytes(finalBytes);

      setState(() {
        _qualityOk = true;
        _qualityMessage = null;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context).pop(outFile);
    } catch (e) {
      _showError('Gagal mengambil foto: $e');
      await _safeStartStream();
      setState(() => _isTakingPhoto = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: _ROIOverlay(
                  roiRatio: _roiRatio,
                  handDetected: _handDetected,
                  detectedHands: _detectedHands,
                  sensorOrientation: _controller!.description.sensorOrientation,
                ),
              ),

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

            if (_isInitialized)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _qualityMessage != null
                      ? _buildFeedbackBox(
                          key: const ValueKey('error'),
                          color: Colors.red,
                          icon: Icons.warning_rounded,
                          text: _qualityMessage!,
                        )
                      : _qualityOk
                      ? _buildFeedbackBox(
                          key: const ValueKey('success'),
                          color: Colors.green,
                          icon: Icons.check_circle_rounded,
                          text: 'Foto berhasil diambil!',
                        )
                      : _buildFeedbackBox(
                          key: ValueKey(_palmGuideMessage),
                          color: _handDetected ? Colors.green : Colors.orange,
                          icon: _handDetected
                              ? Icons.back_hand
                              : Icons.pan_tool_alt_outlined,
                          text: _palmGuideMessage,
                        ),
                ),
              ),

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

            if (_isInitialized && _handDetected)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: _isTakingPhoto
                              ? 1.0
                              : (_autoCaptureDelay.inSeconds - _autoCountdown) /
                                    _autoCaptureDelay.inSeconds,
                          strokeWidth: 4,
                          color: Colors.greenAccent,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Text(
                        _isTakingPhoto ? '📸' : '$_autoCountdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBox({
    required Key key,
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class untuk kirim ke isolate ──
class _PhotoProcessArgs {
  final Uint8List rawBytes;
  final List<List<double>> landmarkXY;
  final int sensorOrientation;

  _PhotoProcessArgs({
    required this.rawBytes,
    required this.landmarkXY,
    required this.sensorOrientation,
  });
}

class _PhotoProcessResult {
  final String? errorMessage;
  final String? filePath;

  _PhotoProcessResult({this.errorMessage, this.filePath});
}

// ── Static function: jalan di isolate terpisah ──
Future<_PhotoProcessResult> _processPhotoInIsolate(
  _PhotoProcessArgs args,
) async {
  // 1. Decode
  img.Image? fullImage = img.decodeImage(args.rawBytes);
  debugPrint('[Isolate] imageSize=${fullImage?.width}x${fullImage?.height}');
  if (fullImage == null) {
    return _PhotoProcessResult(errorMessage: 'Gagal decode gambar');
  }

  // 2. Resize ke max 1080px
  img.Image resized = _resizeKeepAspectStatic(fullImage, maxSize: 1080);

  // 3. Crop ROI 128 x 128 berdasarkan palm center landmark
  final img.Image? croppedRegion = cropByLandmarkRoiMediapipe(
    resized,
    args.landmarkXY,
    args.sensorOrientation,
    isFrontCamera: true,
  );

  if (croppedRegion == null) {
    return _PhotoProcessResult(
      errorMessage:
          'Gagal membaca area tangan.\nPastikan telapak terlihat jelas.',
    );
  }

  // 4. Quality check pada crop
  final String? qualityError = _checkQualityStatic(croppedRegion);
  if (qualityError != null) {
    return _PhotoProcessResult(errorMessage: qualityError);
  }

  // 5. Pastikan 200×200 grayscale lalu encode JPEG
  final Uint8List jpegBytes =
      img.encodeJpg(croppedRegion!, quality: 95) as Uint8List;

  final String b64 = base64Encode(jpegBytes);
  return _PhotoProcessResult(filePath: b64);
}

img.Image _resizeKeepAspectStatic(img.Image src, {required int maxSize}) {
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

img.Image? _cropByLandmarkStatic(
  img.Image image,
  List<List<double>> lmXY,
  int sensorOrientation,
) {
  try {
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    Offset transformLm(double x, double y) {
      switch (sensorOrientation) {
        case 90:
          return Offset((1.0 - y) * w, x * h);
        case 270:
          return Offset(y * w, (1.0 - x) * h);
        case 180:
          return Offset((1.0 - x) * w, (1.0 - y) * h);
        default:
          return Offset(x * w, y * h);
      }
    }

    final wrist = transformLm(lmXY[0][0], lmXY[0][1]);
    final indexMcp = transformLm(lmXY[5][0], lmXY[5][1]);
    final middleMcp = transformLm(lmXY[9][0], lmXY[9][1]);
    final ringMcp = transformLm(lmXY[13][0], lmXY[13][1]);
    final pinkyMcp = transformLm(lmXY[17][0], lmXY[17][1]);

    // ── 1. Angle: wrist→middleMcp terhadap sumbu Y, clamp ±5° (sinkron server) ──
    final dx = middleMcp.dx - wrist.dx;
    final dy = middleMcp.dy - wrist.dy;
    double angle = atan2(dx, -dy) * 180 / pi;
    angle = angle.clamp(-5.0, 5.0); // sinkron dengan ALIGN_ANGLE_MAX server

    // ── 2. Dynamic ROI size: knuckleDist × 1.15 (sinkron server)
    final knuckleDist = sqrt(
      pow(pinkyMcp.dx - indexMcp.dx, 2) + pow(pinkyMcp.dy - indexMcp.dy, 2),
    );
    final dynamicSize = (knuckleDist * 1.15).clamp(80.0, 200.0);

    // ── 3. Palm center: anchor = avg 4 MCP, offset 0.52 (sinkron server) ──
    final anchorX = (indexMcp.dx + middleMcp.dx + ringMcp.dx + pinkyMcp.dx) / 4;
    final anchorY = (indexMcp.dy + middleMcp.dy + ringMcp.dy + pinkyMcp.dy) / 4;

    final vx = pinkyMcp.dx - indexMcp.dx;
    final vy = pinkyMcp.dy - indexMcp.dy;
    final palmWidth = sqrt(vx * vx + vy * vy);
    if (palmWidth < 1) return null;

    var nx = -vy / palmWidth;
    var ny = vx / palmWidth;

    // Pastikan normal mengarah ke wrist
    final wx = wrist.dx - anchorX;
    final wy = wrist.dy - anchorY;
    if (nx * wx + ny * wy < 0) {
      nx = -nx;
      ny = -ny;
    }

    final offset = palmWidth * 0.52;
    final pcx = anchorX + nx * offset;
    final pcy = anchorY + ny * offset;

    debugPrint(
      '[Crop] pcx=${pcx.toStringAsFixed(1)} pcy=${pcy.toStringAsFixed(1)} '
      'dynamicSize=${dynamicSize.toStringAsFixed(1)} '
      'knuckleDist=${knuckleDist.toStringAsFixed(1)} '
      'offset=${offset.toStringAsFixed(1)} '
      'angle=${angle.toStringAsFixed(1)}°',
    );

    // ── 4. Crop area besar di sekitar palm center ──
    final bigSize = (dynamicSize * 1.2).clamp(80.0, min(w, h));
    final bigHalf = bigSize / 2;

    if (w < bigSize || h < bigSize) return null;

    final bx1 = (pcx - bigHalf).clamp(0.0, w - bigSize);
    final by1 = (pcy - bigHalf).clamp(0.0, h - bigSize);

    final bigCrop = img.copyCrop(
      image,
      x: bx1.toInt(),
      y: by1.toInt(),
      width: bigSize.toInt(),
      height: bigSize.toInt(),
    );

    // ── 5. Rotasi agar jari mengarah ke atas ──
    final img.Image rotated = img.copyRotate(bigCrop, angle: -angle);

    // ── 6. Crop tengah ke dynamicSize ──
    final rw = rotated.width.toDouble();
    final rh = rotated.height.toDouble();
    final half = dynamicSize / 2;

    if (rw < dynamicSize || rh < dynamicSize) return null;

    final cx1 = (rw / 2 - half).clamp(0.0, rw - dynamicSize);
    final cy1 = (rh / 2 - half).clamp(0.0, rh - dynamicSize);

    final finalCrop = img.copyCrop(
      rotated,
      x: cx1.toInt(),
      y: cy1.toInt(),
      width: dynamicSize.toInt(),
      height: dynamicSize.toInt(),
    );

    // ── 7. Resize ke 200×200 ──
    return img.copyResize(
      finalCrop,
      width: 200,
      height: 200,
      interpolation: img.Interpolation.average,
    );
  } catch (e, stack) {
    debugPrint('[Crop] Error: $e\n$stack');
    return null;
  }
}

String? _checkQualityStatic(img.Image cropped) {
  final gray = img.grayscale(cropped);
  double sum = 0, sumSq = 0, totalLum = 0, totalSq = 0;
  int count = 0;
  final pixels = gray.width * gray.height;

  for (int y = 0; y < gray.height; y++) {
    for (int x = 0; x < gray.width; x++) {
      final v = img.getLuminance(gray.getPixel(x, y)).toDouble();
      totalLum += v;
      totalSq += v * v;
      if (x > 0 && x < gray.width - 1 && y > 0 && y < gray.height - 1) {
        final center = v;
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
  }

  final mean = sum / count;
  final blurScore = (sumSq / count) - (mean * mean);
  final brightness = totalLum / pixels;
  final meanLum = totalLum / pixels;
  final variance = (totalSq / pixels) - (meanLum * meanLum);
  final contrast = variance > 0 ? sqrt(variance.abs()) : 0;

  debugPrint(
    '[Quality] blur=$blurScore brightness=$brightness contrast=$contrast',
  );
  if (blurScore < 8)
    return 'Foto terlalu blur.\nPastikan kamera fokus dan tangan tidak bergerak.';
  if (brightness < 40)
    return 'Foto terlalu gelap.\nPindah ke tempat yang lebih terang.';
  if (brightness > 230)
    return 'Foto terlalu terang.\nHindari cahaya langsung ke kamera.';
  if (contrast < 2)
    return 'Detail telapak tangan tidak terlihat.\nPastikan telapak menghadap kamera.';

  final dirtyCheck = _checkDirtyHand(gray);
  if (dirtyCheck != null) return dirtyCheck;

  return null;
}

String? _checkDirtyHand(img.Image gray) {
  final w = gray.width;
  final h = gray.height;

  double totalSum = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      totalSum += img.getLuminance(gray.getPixel(x, y)).toDouble();
    }
  }
  final globalMean = totalSum / (w * h);

  const blockSize = 4;
  int suspiciousBlockCount = 0;
  int totalBlocks = 0;

  for (int by = 0; by + blockSize <= h; by += blockSize) {
    for (int bx = 0; bx + blockSize <= w; bx += blockSize) {
      double blockSum = 0;
      int count = 0;
      for (int y = by; y < by + blockSize; y++) {
        for (int x = bx; x < bx + blockSize; x++) {
          blockSum += img.getLuminance(gray.getPixel(x, y)).toDouble();
          count++;
        }
      }
      final blockMean = blockSum / count;
      totalBlocks++;

      final threshold = (globalMean * 0.75).clamp(30.0, 90.0);
      if (blockMean < threshold && globalMean > 50) {
        suspiciousBlockCount++;
      }
    }
  }

  final dirtyRatio = suspiciousBlockCount / totalBlocks;

  debugPrint(
    '[DirtyHand] globalMean=${globalMean.toStringAsFixed(1)} '
    'suspicious=$suspiciousBlockCount/$totalBlocks '
    'ratio=${(dirtyRatio * 100).toStringAsFixed(1)}%',
  );

  if (dirtyRatio > 0.301) {
    return 'Telapak tangan terdeteksi kotor.\nBersihkan tangan sebelum absensi.';
  }

  return null;
}

// =====================================================================
// ROI Overlay
// =====================================================================

class _ROIOverlay extends StatelessWidget {
  final double roiRatio;
  final bool handDetected;
  final List<Hand>? detectedHands;
  final int sensorOrientation;

  const _ROIOverlay({
    required this.roiRatio,
    required this.handDetected,
    required this.sensorOrientation,
    this.detectedHands,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ROIPainter(
        roiRatio: roiRatio,
        handDetected: handDetected,
        detectedHands: detectedHands,
        sensorOrientation: sensorOrientation,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ROIPainter extends CustomPainter {
  final double roiRatio;
  final bool handDetected;
  final List<Hand>? detectedHands;
  final int sensorOrientation;

  const _ROIPainter({
    required this.roiRatio,
    required this.handDetected,
    required this.sensorOrientation,
    this.detectedHands,
  });

  Offset _transformLandmark(double x, double y, Size size) {
    Offset result;
    switch (sensorOrientation) {
      case 90:
        result = Offset((1.0 - y) * size.width, x * size.height);
        break;
      case 270:
        result = Offset(y * size.width, (1.0 - x) * size.height);
        break;
      case 180:
        result = Offset((1.0 - x) * size.width, (1.0 - y) * size.height);
        break;
      default:
        result = Offset(x * size.width, y * size.height);
    }
    return Offset(size.width - result.dx, result.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // final boxSize = size.width * roiRatio;
    // final left = (size.width - boxSize) / 2;
    // final top = (size.height - boxSize) / 2 - size.height * 0.08;
    // final rect = Rect.fromLTWH(left, top, boxSize, boxSize);

    // final overlayPath = Path()
    //   ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
    //   ..addRect(rect)
    //   ..fillType = PathFillType.evenOdd;
    // canvas.drawPath(
    //   overlayPath,
    //   Paint()..color = Colors.black.withOpacity(0.55),
    // );

    // final borderColor = handDetected ? Colors.greenAccent : Colors.white;
    // canvas.drawRect(
    //   rect,
    //   Paint()
    //     ..color = borderColor
    //     ..style = PaintingStyle.stroke
    //     ..strokeWidth = 2.5,
    // );

    // final cornerPaint = Paint()
    //   ..color = handDetected ? Colors.greenAccent : Colors.lightBlueAccent
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 4
    //   ..strokeCap = StrokeCap.round;

    // const cLen = 24.0;
    // canvas.drawLine(Offset(left, top + cLen), Offset(left, top), cornerPaint);
    // canvas.drawLine(Offset(left, top), Offset(left + cLen, top), cornerPaint);
    // canvas.drawLine(
    //   Offset(left + boxSize - cLen, top),
    //   Offset(left + boxSize, top),
    //   cornerPaint,
    // );
    // canvas.drawLine(
    //   Offset(left + boxSize, top),
    //   Offset(left + boxSize, top + cLen),
    //   cornerPaint,
    // );
    // canvas.drawLine(
    //   Offset(left, top + boxSize - cLen),
    //   Offset(left, top + boxSize),
    //   cornerPaint,
    // );
    // canvas.drawLine(
    //   Offset(left, top + boxSize),
    //   Offset(left + cLen, top + boxSize),
    //   cornerPaint,
    // );
    // canvas.drawLine(
    //   Offset(left + boxSize - cLen, top + boxSize),
    //   Offset(left + boxSize, top + boxSize),
    //   cornerPaint,
    // );
    // canvas.drawLine(
    //   Offset(left + boxSize, top + boxSize - cLen),
    //   Offset(left + boxSize, top + boxSize),
    //   cornerPaint,
    // );

    if (handDetected && detectedHands != null && detectedHands!.isNotEmpty) {
      final hand = detectedHands!.first;
      // final roiRect = Rect.fromLTWH(left, top, boxSize, boxSize);

      final linePaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final dotPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.fill;

      Offset lmToOffset(landmark) =>
          _transformLandmark(landmark.x, landmark.y, size);
      // bool isInRoi(Offset p) => roiRect.contains(p);

      final connections = [
        [0, 1],
        [1, 2],
        [2, 3],
        [3, 4],
        [0, 5],
        [5, 6],
        [6, 7],
        [7, 8],
        [0, 9],
        [9, 10],
        [10, 11],
        [11, 12],
        [0, 13],
        [13, 14],
        [14, 15],
        [15, 16],
        [0, 17],
        [17, 18],
        [18, 19],
        [19, 20],
        [5, 9],
        [9, 13],
        [13, 17],
      ];

      for (final conn in connections) {
        final p1 = lmToOffset(hand.landmarks[conn[0]]);
        final p2 = lmToOffset(hand.landmarks[conn[1]]);
        canvas.drawLine(p1, p2, linePaint);
      }

      for (final landmark in hand.landmarks) {
        final p = lmToOffset(landmark);
        canvas.drawCircle(p, 4, dotPaint);
      }
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: handDetected ? 'TANGAN TERDETEKSI ✓' : 'AREA SCAN',
        style: TextStyle(
          color: handDetected ? Colors.greenAccent : Colors.lightBlueAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(16, 16));
  }

  @override
  bool shouldRepaint(covariant _ROIPainter old) =>
      old.roiRatio != roiRatio ||
      old.handDetected != handDetected ||
      old.detectedHands != detectedHands ||
      old.sensorOrientation != sensorOrientation;
}
