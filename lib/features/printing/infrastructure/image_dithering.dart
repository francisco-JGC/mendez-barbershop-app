import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../domain/receipt.dart';

/// 1:1 port of `mendez-barbershop-client/src/lib/receipt-image.ts`.
///
/// Converts a base64 data URL logo into a 1-bit-per-pixel bitmap sized for a
/// thermal printer, using Floyd–Steinberg dithering so grayscale looks decent.
class ReceiptImageEncoder {
  const ReceiptImageEncoder();

  /// [dataUrl] can be `data:image/png;base64,...` or raw base64. Returns null
  /// when the input is empty or fails to decode — callers should treat that as
  /// "no logo" and skip printing it (mirrors the web behaviour).
  ReceiptBitmap? encode(String? dataUrl, {required int maxWidthDots}) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final bytes = _decodeDataUrl(dataUrl);
    if (bytes == null) return null;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Fit within maxWidthDots keeping aspect ratio, round width down to a
    // multiple of 8 (raster bitmaps pack 8 px per byte).
    final scale =
        (maxWidthDots / decoded.width).clamp(0.0, 1.0).toDouble();
    final widthDots =
        ((decoded.width * scale) ~/ 8) * 8 < 8 ? 8 : ((decoded.width * scale) ~/ 8) * 8;
    final heightDots =
        ((decoded.height * widthDots) / decoded.width).round().clamp(1, 1 << 15);

    // Resize + composite over white (transparent PNGs would otherwise become
    // solid black under a hard threshold).
    final resized = img.copyResize(decoded, width: widthDots, height: heightDots);
    final canvas = img.Image(width: widthDots, height: heightDots);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, resized);

    final gray = Float32List(widthDots * heightDots);
    for (var y = 0; y < heightDots; y++) {
      for (var x = 0; x < widthDots; x++) {
        final p = canvas.getPixel(x, y);
        final a = p.a / 255.0;
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        gray[y * widthDots + x] = lum * a + 255 * (1 - a);
      }
    }

    final widthBytes = widthDots ~/ 8;
    final out = Uint8List(widthBytes * heightDots);

    for (var y = 0; y < heightDots; y++) {
      for (var x = 0; x < widthDots; x++) {
        final idx = y * widthDots + x;
        final oldPixel = gray[idx];
        final newPixel = oldPixel < 128 ? 0.0 : 255.0;
        final error = oldPixel - newPixel;
        gray[idx] = newPixel;

        // Distribute quantization error to unprocessed neighbours.
        if (x + 1 < widthDots) gray[idx + 1] += error * 7 / 16;
        if (y + 1 < heightDots) {
          if (x > 0) gray[idx + widthDots - 1] += error * 3 / 16;
          gray[idx + widthDots] += error * 5 / 16;
          if (x + 1 < widthDots) gray[idx + widthDots + 1] += error * 1 / 16;
        }

        if (newPixel == 0) {
          final byteIndex = y * widthBytes + (x >> 3);
          out[byteIndex] |= 1 << (7 - (x & 7));
        }
      }
    }

    return ReceiptBitmap(
      widthDots: widthDots,
      heightDots: heightDots,
      bytes: out,
    );
  }

  Uint8List? _decodeDataUrl(String dataUrl) {
    try {
      final commaIndex = dataUrl.indexOf(',');
      final b64 = commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
