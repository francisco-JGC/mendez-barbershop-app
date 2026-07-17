import 'dart:typed_data';

/// 1:1 port of the web client's `ReceiptBuilder` (see `mendez-barbershop-client/src/lib/escpos.ts`).
/// Emits raw ESC/POS bytes so tickets from the web POS and the mobile POS are byte-identical.
class ReceiptBuilder {
  ReceiptBuilder() {
    _bytes.addAll(const [_esc, 0x40]); // ESC @ — initialize printer
  }

  static const int _esc = 0x1b;
  static const int _gs = 0x1d;
  static const int _lf = 0x0a;

  final List<int> _bytes = <int>[];

  ReceiptBuilder align(TextAlign mode) {
    _bytes.addAll([_esc, 0x61, mode.code]);
    return this;
  }

  ReceiptBuilder bold(bool on) {
    _bytes.addAll([_esc, 0x45, on ? 1 : 0]);
    return this;
  }

  ReceiptBuilder doubleHeight(bool on) {
    _bytes.addAll([_gs, 0x21, on ? 0x01 : 0x00]);
    return this;
  }

  ReceiptBuilder text(String line) {
    _bytes.addAll(_encodeAscii(line));
    return this;
  }

  ReceiptBuilder line([String text = '']) => this.text(text).newline();

  ReceiptBuilder newline([int times = 1]) {
    for (var i = 0; i < times; i++) {
      _bytes.add(_lf);
    }
    return this;
  }

  ReceiptBuilder divider(int width, {String char = '-'}) =>
      line(char * width);

  ReceiptBuilder cut() {
    _bytes.addAll([_gs, 0x56, 0x00]); // GS V 0 — full cut
    return this;
  }

  /// Emits a raster bitmap using `GS v 0`. [widthDots] must be a multiple of 8.
  /// [bytes] length must equal `(widthDots / 8) * heightDots`, MSB = leftmost pixel.
  ReceiptBuilder rasterImage(
    int widthDots,
    int heightDots,
    Uint8List bytes,
  ) {
    final widthBytes = widthDots ~/ 8;
    _bytes.addAll([
      _gs, 0x76, 0x30, 0x00,
      widthBytes & 0xff,
      (widthBytes >> 8) & 0xff,
      heightDots & 0xff,
      (heightDots >> 8) & 0xff,
    ]);
    _bytes.addAll(bytes);
    return this;
  }

  Uint8List build() => Uint8List.fromList(_bytes);
}

enum TextAlign {
  left(0),
  center(1),
  right(2);

  const TextAlign(this.code);
  final int code;
}

// Combining diacritics (U+0300–U+036F) that NFD leaves behind.
final _combiningDiacritics = RegExp(r'[̀-ͯ]');
// U+00A0 non-breaking space.
final _nonBreakingSpace = RegExp(' ');

/// Thermal printers expect a single-byte codepage (usually CP437), not UTF-8.
/// Diacritics are stripped rather than mapped, matching the web client exactly.
List<int> _encodeAscii(String text) {
  final normalized = _stripDiacritics(text).replaceAll(_nonBreakingSpace, ' ');
  return normalized.runes.map((code) => code < 128 ? code : 0x3f).toList();
}

/// NFD normalize + strip combining marks. Dart doesn't ship an NFD normalizer
/// in the core lib, so we do it via a small manual pass over Latin diacritics
/// commonly used in ES text (accents, tilde, ü, ñ). Anything else falls through
/// unchanged and gets substituted with '?' downstream.
String _stripDiacritics(String input) {
  const map = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'Á': 'A', 'À': 'A',
    'Ä': 'A', 'Â': 'A', 'Ã': 'A',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'É': 'E', 'È': 'E', 'Ë': 'E',
    'Ê': 'E',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'Í': 'I', 'Ì': 'I', 'Ï': 'I',
    'Î': 'I',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'Ó': 'O', 'Ò': 'O',
    'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'Ú': 'U', 'Ù': 'U', 'Ü': 'U',
    'Û': 'U',
    'ñ': 'n', 'Ñ': 'N',
    'ç': 'c', 'Ç': 'C',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(map[ch] ?? ch);
  }
  // Also strip any lingering combining marks from any wider NFD-like input.
  return buffer.toString().replaceAll(_combiningDiacritics, '');
}

/// Lays [left] and [right] on one line, padding with spaces up to [width].
/// Mirrors the web `twoColumns()` helper 1:1.
String twoColumns(String left, String right, int width) {
  final maxLeftWidth = (width - right.length - 1).clamp(0, width);
  final clippedLeft =
      left.length > maxLeftWidth ? left.substring(0, maxLeftWidth) : left;
  final padding = (width - clippedLeft.length - right.length).clamp(1, width);
  return clippedLeft + ' ' * padding + right;
}
