import 'dart:typed_data';

/// Manual ESC/POS builder. Preferred over `esc_pos_utils_plus` for cheap
/// PT-210 clones because we control the *exact* number of characters emitted
/// per line — the grid layout in esc_pos_utils_plus computes column positions
/// as absolute pixel offsets based on a paper size the printer often ignores,
/// which is why columns kept falling off the paper.
class ReceiptBuilder {
  ReceiptBuilder() {
    // Full reset sequence. Cheap PT-210/GOOJPRT clones ignore `ESC @` alone
    // and keep whatever font/codepage/print-mode the previous session left
    // dangling. FS . is critical: many boot in "Chinese character mode" where
    // every char occupies double width — that's the "32-char line wraps to
    // 3 lines" symptom.
    _bytes.addAll(const [
      _esc, 0x40, // ESC @   — initialize
      _fs, 0x2E, // FS .    — cancel Chinese char mode (KEY for clones)
      _esc, 0x21, 0x00, // ESC ! 0 — cancel bold / DW / DH / underline
      _esc, 0x4D, 0x00, // ESC M 0 — Font A (12x24 dots)
      _esc, 0x74, 0x00, // ESC t 0 — CP437 code page
      _esc, 0x52, 0x00, // ESC R 0 — international char set: USA
      _esc, 0x33, 0x18, // ESC 3 24 — 24-dot line spacing (default)
      _esc, 0x61, 0x00, // ESC a 0 — left align
      _gs, 0x21, 0x00, // GS !  0 — normal char size
    ]);
  }

  static const int _esc = 0x1b;
  static const int _gs = 0x1d;
  static const int _fs = 0x1c;
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

  ReceiptBuilder divider(int width, {String char = '-'}) => line(char * width);

  ReceiptBuilder cut() {
    _bytes.addAll([_gs, 0x56, 0x00]); // GS V 0 — full cut
    return this;
  }

  /// Emits a raster bitmap using `GS v 0`. [widthDots] must be a multiple of 8.
  ReceiptBuilder rasterImage(int widthDots, int heightDots, Uint8List bytes) {
    final widthBytes = widthDots ~/ 8;
    _bytes.addAll([
      _gs, 0x76, 0x30, 0x00,
      widthBytes & 0xff, (widthBytes >> 8) & 0xff,
      heightDots & 0xff, (heightDots >> 8) & 0xff,
    ]);
    _bytes.addAll(bytes);
    return this;
  }

  List<int> build() => List<int>.from(_bytes);
}

enum TextAlign {
  left(0),
  center(1),
  right(2);

  const TextAlign(this.code);
  final int code;
}

/// Lays [left] and [right] on one line, padding with spaces up to [width].
/// If [left] doesn't fit alongside [right], it's clipped so [right] always
/// lands flush at column [width].
String twoColumns(String left, String right, int width) {
  final maxLeftWidth = (width - right.length - 1).clamp(0, width);
  final clippedLeft =
      left.length > maxLeftWidth ? left.substring(0, maxLeftWidth) : left;
  final padding = (width - clippedLeft.length - right.length).clamp(1, width);
  return clippedLeft + ' ' * padding + right;
}

// Strip Spanish diacritics. CP437 is default on clones; even when we set
// CP850 above, some firmwares silently ignore it. Better to render "a" than a
// garbage char.
final _combiningDiacritics = RegExp(r'[̀-ͯ]');

List<int> _encodeAscii(String text) {
  final normalized = _stripDiacritics(text);
  return normalized.runes.map((code) => code < 128 ? code : 0x3f).toList();
}

String _stripDiacritics(String input) {
  const map = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
    'ñ': 'n', 'Ñ': 'N',
    'ç': 'c', 'Ç': 'C',
  };
  final buf = StringBuffer();
  for (final r in input.runes) {
    final ch = String.fromCharCode(r);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString().replaceAll(_combiningDiacritics, '');
}
