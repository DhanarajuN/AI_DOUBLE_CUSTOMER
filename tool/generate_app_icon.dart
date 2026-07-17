// One-off generator for the app icon, matching AppColors in
// lib/theme/app_theme.dart: a teal-gradient background holding a single
// speech-bubble mark with a checkmark cut out of it — an AI conversation
// that resolves into a confirmed outcome (a booked appointment, a settled
// claim), which is what this app's agents actually do. No lettering/badge.
//
// Adaptive icons (Android 8+) composite two separate layers that the OS
// clips into whatever shape the launcher uses (circle, squircle, teardrop,
// ...), so the background here is a full-bleed gradient with no shape of
// its own — it should never show empty space around it — while the
// foreground is just the glyph, sized to fit inside the ~66% "safe zone"
// so it isn't clipped regardless of mask shape.
//
// Run with `dart run tool/generate_app_icon.dart`, then apply the result
// with `dart run flutter_launcher_icons` (see flutter_launcher_icons.yaml).
// Not part of the shipped app — safe to delete once the PNGs it writes to
// assets/icon/ look right.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _teal = (0x12, 0xB8, 0x86); // AppColors.appPrimaryColor
const _tealDeep = (0x0A, 0x5C, 0x48); // AppColors.appPrimaryDarkColor

void main() {
  Directory('assets/icon').createSync(recursive: true);

  _renderBackground('assets/icon/icon_background.png', size: 1024);
  _renderFlatIcon('assets/icon/icon.png', size: 1024, referenceHalf: 340);
  _renderForeground('assets/icon/icon_foreground.png', size: 1024, referenceHalf: 260);

  stdout.writeln('Wrote icon_background.png, icon.png and icon_foreground.png to assets/icon/');
}

/// Full-bleed diagonal teal gradient, no shapes — the adaptive icon
/// background layer, and the base the flat icon draws its glyph over.
void _renderBackground(String outPath, {required int size}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = ((x / size) + (y / size)) / 2;
      final c = _lerpColor(_teal, _tealDeep, t.clamp(0.0, 1.0));
      image.setPixelRgba(x, y, c.$1, c.$2, c.$3, 255);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

/// Gradient + glyph flattened into one square — used for the legacy/iOS/web
/// launcher icon, where there's no adaptive safe-zone constraint.
void _renderFlatIcon(String outPath, {required int size, required double referenceHalf}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final center = size / 2;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = ((x / size) + (y / size)) / 2;
      final bg = _lerpColor(_teal, _tealDeep, t.clamp(0.0, 1.0));
      final rgba = _glyphPixel(x + 0.5 - center, y + 0.5 - center, referenceHalf, bg, 255);
      image.setPixelRgba(x, y, rgba.$1, rgba.$2, rgba.$3, rgba.$4);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

/// Just the glyph on a transparent canvas — the adaptive icon foreground
/// layer, composited by the OS on top of [_renderBackground]'s output.
void _renderForeground(String outPath, {required int size, required double referenceHalf}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final center = size / 2;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final rgba = _glyphPixel(x + 0.5 - center, y + 0.5 - center, referenceHalf, (0, 0, 0), 0);
      image.setPixelRgba(x, y, rgba.$1, rgba.$2, rgba.$3, rgba.$4);
    }
  }
  File(outPath).writeAsBytesSync(img.encodePng(image));
}

/// Draws a rounded speech bubble (with tail) over [bg]/[bgAlpha] at the
/// given pixel, relative to the icon center, then cuts a checkmark out of
/// it as negative space — revealing [bg]/[bgAlpha] again (the gradient on
/// the flat icon, transparency on the adaptive foreground) so the check
/// reads as part of the same background layer showing through.
(int, int, int, int) _glyphPixel(double px, double py, double refHalf, (int, int, int) bg, int bgAlpha) {
  final bgR = bg.$1.toDouble();
  final bgG = bg.$2.toDouble();
  final bgB = bg.$3.toDouble();
  final bgA = bgAlpha.toDouble();
  var r = bgR;
  var g = bgG;
  var b = bgB;
  var a = bgA;

  const bubbleCx = 0.0;
  const bubbleCy = -0.05;
  final halfW = refHalf * 0.54;
  final halfH = refHalf * 0.38;
  final corner = halfH * 0.55;
  final bx = px - refHalf * bubbleCx;
  final by = py - refHalf * bubbleCy;
  var bubbleCov = _coverage(_sdRoundRect(bx, by, halfW, halfH, corner));

  final t1 = (refHalf * bubbleCx - halfW * 0.42, refHalf * bubbleCy + halfH * 0.82);
  final t2 = (refHalf * bubbleCx - halfW * 0.02, refHalf * bubbleCy + halfH * 0.98);
  final t3 = (refHalf * bubbleCx - halfW * 0.62, refHalf * bubbleCy + halfH * 1.62);
  if (_insideTriangle(px, py, t1.$1, t1.$2, t2.$1, t2.$2, t3.$1, t3.$2)) {
    bubbleCov = 1.0;
  }

  if (bubbleCov > 0) {
    r = _lerp(r, 255.0, bubbleCov);
    g = _lerp(g, 255.0, bubbleCov);
    b = _lerp(b, 255.0, bubbleCov);
    a = _lerp(a, 255.0, bubbleCov);
  }

  // Checkmark: short down-stroke then a longer up-stroke to the right,
  // both drawn as capsules and cut out of the bubble fill.
  final stroke = refHalf * 0.095;
  final c1 = (refHalf * bubbleCx - halfW * 0.38, refHalf * bubbleCy - halfH * 0.02);
  final c2 = (refHalf * bubbleCx - halfW * 0.06, refHalf * bubbleCy + halfH * 0.36);
  final c3 = (refHalf * bubbleCx + halfW * 0.50, refHalf * bubbleCy - halfH * 0.38);
  final checkDist = math.min(
    _sdSegment(px, py, c1.$1, c1.$2, c2.$1, c2.$2) - stroke,
    _sdSegment(px, py, c2.$1, c2.$2, c3.$1, c3.$2) - stroke,
  );
  final checkCov = _coverage(checkDist);
  if (checkCov > 0) {
    r = _lerp(r, bgR, checkCov);
    g = _lerp(g, bgG, checkCov);
    b = _lerp(b, bgB, checkCov);
    a = _lerp(a, bgA, checkCov);
  }

  return (r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255), a.round().clamp(0, 255));
}

(int, int, int) _lerpColor((int, int, int) a, (int, int, int) b, double t) => (
      _lerp(a.$1.toDouble(), b.$1.toDouble(), t).round(),
      _lerp(a.$2.toDouble(), b.$2.toDouble(), t).round(),
      _lerp(a.$3.toDouble(), b.$3.toDouble(), t).round(),
    );

// Signed-distance field for a rounded rectangle (negative = inside).
// Standard formulation, see Inigo Quilez's 2D distance function notes.
double _sdRoundRect(double px, double py, double halfW, double halfH, double r) {
  final qx = px.abs() - halfW + r;
  final qy = py.abs() - halfH + r;
  final ax = math.max(qx, 0.0);
  final ay = math.max(qy, 0.0);
  return math.sqrt(ax * ax + ay * ay) + math.min(math.max(qx, qy), 0.0) - r;
}

bool _insideTriangle(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  double sign(double x1, double y1, double x2, double y2, double x3, double y3) =>
      (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3);
  final d1 = sign(px, py, ax, ay, bx, by);
  final d2 = sign(px, py, bx, by, cx, cy);
  final d3 = sign(px, py, cx, cy, ax, ay);
  final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
  final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
  return !(hasNeg && hasPos);
}

// Distance from a point to a line segment (a rounded "capsule" stroke).
double _sdSegment(double px, double py, double ax, double ay, double bx, double by) {
  final ex = bx - ax;
  final ey = by - ay;
  final wx = px - ax;
  final wy = py - ay;
  final t = ((wx * ex + wy * ey) / (ex * ex + ey * ey)).clamp(0.0, 1.0);
  final cx = ax + ex * t;
  final cy = ay + ey * t;
  final dx = px - cx;
  final dy = py - cy;
  return math.sqrt(dx * dx + dy * dy);
}

double _coverage(double signedDistance) => (0.5 - signedDistance).clamp(0.0, 1.0);

double _lerp(double a, double b, double t) => a + (b - a) * t;
