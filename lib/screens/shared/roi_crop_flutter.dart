// =============================================================================
// ROI CROP — mirror dari roi_mediapipe.py
// Ganti seluruh fungsi _cropByLandmarkStatic di file Flutter kamu dengan ini.
// Juga update output size di _processPhotoInIsolate (200→128).
// =============================================================================

import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// KONSTANTA — harus sama persis dengan roi_mediapipe.py
// ---------------------------------------------------------------------------
const int _roiSize = 128; // ROI_SIZE
const double _offsetTop = 0.05; // OFFSET_TOP
const double _offsetBottom = 0.85; // OFFSET_BOTTOM
const double _offsetLeft = 0.00; // OFFSET_LEFT
const double _offsetRight = 0.05; // OFFSET_RIGHT
const double _widthScale = 0.85; // WIDTH_SCALE

// ---------------------------------------------------------------------------
// Helper: 2-D vector sederhana (biar kode mudah dibaca)
// ---------------------------------------------------------------------------
class _Vec2 {
  final double x, y;
  const _Vec2(this.x, this.y);

  _Vec2 operator +(_Vec2 o) => _Vec2(x + o.x, y + o.y);
  _Vec2 operator -(_Vec2 o) => _Vec2(x - o.x, y - o.y);
  _Vec2 operator *(double s) => _Vec2(x * s, y * s);
  double get norm => sqrt(x * x + y * y);
  _Vec2 get normalized => norm < 1e-9 ? const _Vec2(0, 0) : this * (1.0 / norm);
  double dot(_Vec2 o) => x * o.x + y * o.y;

  // Perpendicular: rotate 90° CW  →  (y, -x)
  _Vec2 get perp => _Vec2(y, -x);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

// ---------------------------------------------------------------------------
// _buildQuad  —  mirror dari _build_quad() di Python
//
// lmXY  : List 21 elemen, tiap elemen [normX, normY] (0-1, sudah di-transform)
// w, h  : ukuran gambar dalam piksel
//
// Return: List 4 _Vec2 [TL, TR, BR, BL] dalam piksel,
//         atau null jika landmark tidak bisa dipercaya (→ fallback center crop)
// ---------------------------------------------------------------------------
List<_Vec2>? _buildQuad(List<List<double>> lmXY, double w, double h) {
  // Pixel coords landmark kunci
  final p5x = lmXY[5][0] * w;
  final p5y = lmXY[5][1] * h;
  final p17x = lmXY[17][0] * w;
  final p17y = lmXY[17][1] * h;
  final p9x = lmXY[9][0] * w;
  final p9y = lmXY[9][1] * h;
  final p13x = lmXY[13][0] * w;
  final p13y = lmXY[13][1] * h;
  final p0y = lmXY[0][1] * h; // wrist y

  // ── Tentukan left_pt / right_pt berdasarkan posisi x (sama seperti Python) ──
  _Vec2 leftPt, rightPt;
  if (p5x <= p17x) {
    leftPt = _Vec2(p5x, p5y);
    rightPt = _Vec2(p17x, p17y);
  } else {
    leftPt = _Vec2(p17x, p17y);
    rightPt = _Vec2(p5x, p5y);
  }

  // ── SANITY CHECK ──────────────────────────────────────────────────────────
  final allMcpY = (p5y + p9y + p13y + p17y) / 4;
  final mcpLenCheck = (rightPt - leftPt).norm;

  final landmarkFlipped = allMcpY > h * 0.60;
  final landmarkAbnormal = mcpLenCheck < w * 0.10 || mcpLenCheck > w * 0.80;

  if (landmarkFlipped || landmarkAbnormal) {
    debugPrint(
      '[buildQuad] SANITY FAIL flipped=$landmarkFlipped abnormal=$landmarkAbnormal',
    );
    return null; // → caller pakai center crop
  }

  // ── FALLBACK ANCHOR: P9/P13 bila P5/P17 terlalu ke bawah ─────────────────
  final mcpCenterY = (leftPt.y + rightPt.y) / 2;
  if (mcpCenterY > h * 0.55) {
    if (p9x <= p13x) {
      leftPt = _Vec2(p9x, p9y);
      rightPt = _Vec2(p13x, p13y);
    } else {
      leftPt = _Vec2(p13x, p13y);
      rightPt = _Vec2(p9x, p9y);
    }
  }

  final vecMcp = rightPt - leftPt;
  final mcpLenOrig = vecMcp.norm; // panjang asli → dipakai untuk height

  // Edge case: landmark terlalu dekat satu sama lain
  if (mcpLenOrig < 1e-6) {
    final xs = lmXY.map((p) => p[0] * w).toList();
    final ys = lmXY.map((p) => p[1] * h).toList();
    xs.sort();
    ys.sort();
    return [
      _Vec2(xs.first, ys.first),
      _Vec2(xs.last, ys.first),
      _Vec2(xs.last, ys.last),
      _Vec2(xs.first, ys.last),
    ];
  }

  // ── Unit vector horizontal (kiri→kanan) ──────────────────────────────────
  _Vec2 unitH = vecMcp.normalized;

  // Scale lebar saja; tinggi tetap mcpLenOrig
  final scaledLen = mcpLenOrig * _widthScale;
  final centerPt = leftPt * 0.5 + rightPt * 0.5; // midpoint
  leftPt = centerPt - unitH * (scaledLen / 2);
  rightPt = centerPt + unitH * (scaledLen / 2);
  final mcpLen = scaledLen; // dipakai untuk offset kiri/kanan saja

  // ── Unit vector vertikal: 90° dari unitH, arah ke bawah (ke wrist) ───────
  // Python:  unit_v = [unit_h[1], -unit_h[0]]
  // = rotate unitH 90° CW → (unitH.y, -unitH.x)
  _Vec2 unitV = unitH.perp; // (unitH.y, -unitH.x)

  // Pastikan unitV mengarah ke wrist (P0) bukan ke jari
  // Python: if unit_v[1] < 0 and p0y > mcp_center_y: unit_v = -unit_v
  final mcpCenterYNew = (leftPt.y + rightPt.y) / 2;
  if (unitV.y < 0 && p0y > mcpCenterYNew) {
    unitV = unitV * -1;
  }

  // ── Bangun 4 sudut quad ───────────────────────────────────────────────────
  //   mcpLenOrig untuk arah vertikal (tinggi)
  //   mcpLen (scaled) untuk arah horizontal (lebar)
  var tl =
      leftPt -
      unitV * (_offsetTop * mcpLenOrig) -
      unitH * (_offsetLeft * mcpLen);
  var tr =
      rightPt -
      unitV * (_offsetTop * mcpLenOrig) +
      unitH * (_offsetRight * mcpLen);
  var br =
      rightPt +
      unitV * (_offsetBottom * mcpLenOrig) +
      unitH * (_offsetRight * mcpLen);
  var bl =
      leftPt +
      unitV * (_offsetBottom * mcpLenOrig) -
      unitH * (_offsetLeft * mcpLen);

  // Clamp ke batas gambar
  _Vec2 clampPt(_Vec2 p) => _Vec2(p.x.clamp(0, w - 1), p.y.clamp(0, h - 1));
  tl = clampPt(tl);
  tr = clampPt(tr);
  br = clampPt(br);
  bl = clampPt(bl);

  debugPrint(
    '[buildQuad] TL=$tl TR=$tr BR=$br BL=$bl mcpLenOrig=${mcpLenOrig.toStringAsFixed(1)}',
  );
  return [tl, tr, br, bl];
}

// ---------------------------------------------------------------------------
// _perspectiveWarp  —  mirror dari _perspective_warp() di Python
//
// Karena package `image` Dart tidak punya getPerspectiveTransform bawaan,
// kita hitung matrix 3×3 secara manual (DLT 4-point), lalu warp tiap piksel.
// Ini ekuivalen dengan cv2.getPerspectiveTransform + cv2.warpPerspective.
// ---------------------------------------------------------------------------
img.Image _perspectiveWarp(img.Image src, List<_Vec2> quad, int outSize) {
  // src quad  → TL, TR, BR, BL
  // dst quad  → (0,0), (N-1,0), (N-1,N-1), (0,N-1)
  final n = outSize - 1.0;

  final srcPts = [
    [quad[0].x, quad[0].y], // TL
    [quad[1].x, quad[1].y], // TR
    [quad[2].x, quad[2].y], // BR
    [quad[3].x, quad[3].y], // BL
  ];
  final dstPts = [
    [0.0, 0.0],
    [n, 0.0],
    [n, n],
    [0.0, n],
  ];

  // Hitung homography H (dst → src) supaya kita bisa sample per piksel output
  final H = _computeHomography(dstPts, srcPts);

  final dst = img.Image(width: outSize, height: outSize);

  for (int dy = 0; dy < outSize; dy++) {
    for (int dx = 0; dx < outSize; dx++) {
      // Apply H: warp dst point ke src coords
      final raw = _applyH(H, dx.toDouble(), dy.toDouble());
      final sx = raw[0];
      final sy = raw[1];

      // Bilinear sampling dari src
      final color = _bilinearSample(src, sx, sy);
      dst.setPixel(dx, dy, color);
    }
  }

  return dst;
}

/// Hitung homography 3×3 (represented as flat list row-major, 9 elemen)
/// yang memetakan srcPts[i] → dstPts[i] untuk 4 pasang titik.
/// Menggunakan DLT (Direct Linear Transform).
List<double> _computeHomography(
  List<List<double>> src, // 4 × 2
  List<List<double>> dst, // 4 × 2
) {
  // Susun matriks A (8×8) dan vektor b (8×1)
  // Setiap pasang titik menghasilkan 2 persamaan linier.
  final A = List.generate(8, (_) => List<double>.filled(8, 0.0));
  final b = List<double>.filled(8, 0.0);

  for (int i = 0; i < 4; i++) {
    final sx = src[i][0], sy = src[i][1];
    final dx = dst[i][0], dy = dst[i][1];

    // Baris 2i  : sx → dx
    A[2 * i][0] = sx;
    A[2 * i][1] = sy;
    A[2 * i][2] = 1;
    A[2 * i][6] = -dx * sx;
    A[2 * i][7] = -dx * sy;
    b[2 * i] = dx;

    // Baris 2i+1: sy → dy
    A[2 * i + 1][3] = sx;
    A[2 * i + 1][4] = sy;
    A[2 * i + 1][5] = 1;
    A[2 * i + 1][6] = -dy * sx;
    A[2 * i + 1][7] = -dy * sy;
    b[2 * i + 1] = dy;
  }

  // Selesaikan A·h = b dengan eliminasi Gauss
  final h = _gaussianElimination(A, b);

  // h = [h00,h01,h02, h10,h11,h12, h20,h21],  h22 = 1
  return [...h, 1.0];
}

/// Gauss elimination sederhana untuk sistem 8×8
List<double> _gaussianElimination(List<List<double>> A, List<double> b) {
  final n = 8;
  // Augmented matrix [A|b]
  final M = List.generate(n, (i) => [...A[i], b[i]]);

  for (int col = 0; col < n; col++) {
    // Pivot: cari baris terbesar
    int pivot = col;
    for (int row = col + 1; row < n; row++) {
      if (M[row][col].abs() > M[pivot][col].abs()) pivot = row;
    }
    final tmp = M[col];
    M[col] = M[pivot];
    M[pivot] = tmp;

    final diag = M[col][col];
    if (diag.abs() < 1e-12) continue;

    for (int row = 0; row < n; row++) {
      if (row == col) continue;
      final factor = M[row][col] / diag;
      for (int k = col; k <= n; k++) {
        M[row][k] -= factor * M[col][k];
      }
    }
  }

  return List.generate(n, (i) => M[i][n] / M[i][i]);
}

/// Terapkan matrix H (9 elemen row-major) ke titik (x, y)
List<double> _applyH(List<double> H, double x, double y) {
  final w2 = H[6] * x + H[7] * y + H[8];
  final rx = (H[0] * x + H[1] * y + H[2]) / w2;
  final ry = (H[3] * x + H[4] * y + H[5]) / w2;
  return [rx, ry];
}

/// Bilinear interpolation dari img.Image pada koordinat (sx, sy) float
img.Color _bilinearSample(img.Image src, double sx, double sy) {
  final x0 = sx.floor().clamp(0, src.width - 1);
  final y0 = sy.floor().clamp(0, src.height - 1);
  final x1 = (x0 + 1).clamp(0, src.width - 1);
  final y1 = (y0 + 1).clamp(0, src.height - 1);

  final tx = sx - sx.floor();
  final ty = sy - sy.floor();

  // Untuk grayscale yang kita tuju, ambil luminance saja sudah cukup akurat.
  // Bilinear dilakukan pada nilai luminance agar hasilnya smooth.
  double lum(img.Pixel p) => (p.r * 0.299 + p.g * 0.587 + p.b * 0.114);

  final l00 = lum(src.getPixel(x0, y0));
  final l10 = lum(src.getPixel(x1, y0));
  final l01 = lum(src.getPixel(x0, y1));
  final l11 = lum(src.getPixel(x1, y1));

  final lumFinal =
      (l00 * (1 - tx) + l10 * tx) * (1 - ty) + (l01 * (1 - tx) + l11 * tx) * ty;
  final v = lumFinal.round().clamp(0, 255);

  // Kembalikan sebagai Color (bukan Pixel) — inilah yang diterima oleh
  // Image.setPixel(). ColorRgb8 implements Color, jadi tidak perlu (dan
  // tidak boleh) di-cast ke Pixel.
  return img.ColorRgb8(v, v, v);
}

// =============================================================================
// FUNGSI UTAMA — drop-in replacement untuk _cropByLandmarkStatic
// =============================================================================

/// Crop ROI palmprint dari [image] menggunakan [lmXY] (21 landmark normalized
/// yang sudah di-transform sesuai [sensorOrientation]).
///
/// Return: img.Image 128×128 grayscale, atau null jika fallback gagal.
img.Image? cropByLandmarkRoiMediapipe(
  img.Image image,
  List<List<double>> lmXY,
  int sensorOrientation, {
  bool isFrontCamera = false,
}) {
  try {
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    // ── Transform landmark sesuai sensor orientation ──────────────────────
    List<double> transformLm(double x, double y) {
      double tx, ty;
      switch (sensorOrientation) {
        case 90:
          tx = 1.0 - y;
          ty = x;
          // Kamera depan SO=90: perlu flip horizontal
          if (isFrontCamera) tx = 1.0 - tx;
          break;
        case 270:
          tx = y;
          ty = 1.0 - x;
          // Kamera depan SO=270: TIDAK perlu flip tambahan
          // sudah benar tanpa flip
          break;
        case 180:
          tx = 1.0 - x;
          ty = 1.0 - y;
          if (isFrontCamera) tx = 1.0 - tx;
          break;
        default:
          tx = x;
          ty = y;
          if (isFrontCamera) tx = 1.0 - tx;
      }
      return [tx, ty];
    }

    // Rebuild lmXY dengan koordinat yang sudah di-transform (normalized 0-1)
    final lmT = lmXY.map((p) => transformLm(p[0], p[1])).toList();

    // ── Bangun quad (mirror _build_quad Python) ────────────────────────────
    final quad = _buildQuad(lmT, w, h);

    if (quad == null) {
      // Fallback: center crop 128×128 (mirror Python)
      debugPrint('[cropROI] quad null → center crop fallback');
      return _centerCropFallback(image);
    }

    // ── Perspective warp → 128×128 ────────────────────────────────────────
    final warped = _perspectiveWarp(image, quad, _roiSize);
    final grayRoi = img.grayscale(warped);

    debugPrint('[cropROI] ✓ perspective warp ${_roiSize}×${_roiSize}');
    return grayRoi;
  } catch (e, stack) {
    debugPrint('[cropROI] Error: $e\n$stack');
    return null;
  }
}

/// Center crop fallback — mirror Python: ambil patch ROI_SIZE dari tengah gambar
img.Image _centerCropFallback(img.Image image) {
  final cx = image.width ~/ 2;
  final cy = image.height ~/ 2;
  final half = _roiSize ~/ 2;

  final x = (cx - half).clamp(0, image.width - _roiSize);
  final y = (cy - half).clamp(0, image.height - _roiSize);

  final patch = img.copyCrop(
    image,
    x: x,
    y: y,
    width: _roiSize,
    height: _roiSize,
  );
  final gray = img.grayscale(patch);
  return img.copyResize(gray, width: _roiSize, height: _roiSize);
}
