import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

/// Bitmap primed for ESC/POS raster (`GS v 0`).
class ReceiptBitmap {
  const ReceiptBitmap({
    required this.widthDots,
    required this.heightDots,
    required this.bytes,
  });
  final int widthDots;
  final int heightDots;
  final Uint8List bytes;
}

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });
  final String name;
  final int quantity;
  final String unitPrice;
}

class ReceiptInput {
  const ReceiptInput({
    required this.barbershopName,
    required this.ticketId,
    required this.createdAt,
    required this.lines,
    required this.total,
    required this.paperSize,
    this.barberName,
    this.stationLabel,
    this.footer,
    this.logo,
    this.printBarbershopName = true,
  });

  final String barbershopName;
  final String ticketId;
  final String createdAt;
  final String? barberName;
  final String? stationLabel;
  final List<ReceiptLineItem> lines;
  final String total;
  final String? footer;
  final ReceiptBitmap? logo;
  final bool printBarbershopName;
  final PaperSize paperSize;
}

/// Builds a receipt using the `esc_pos_utils_plus` grid layout (12 cols,
/// absolute column positioning via ESC/POS — no space-padding tricks). This
/// mirrors the approach of the shop's other proven Flutter POS and is what
/// makes cheap PT-210 clones actually align columns.
Future<List<int>> buildReceipt(ReceiptInput input) async {
  final profile = await CapabilityProfile.load();
  final g = Generator(input.paperSize, profile);
  // CP850 covers Spanish accents (ñ, á, é, í, ó, ú, ü). Fall back to the
  // default (CP437) when the printer doesn't advertise CP850 — the diacritic
  // stripping below keeps ASCII output correct in that case too.
  g.setGlobalCodeTable('CP850');

  final bytes = <int>[];
  // Explicit reset so cheap firmwares (PT-210 clones) don't inherit sticky
  // state — double-width, bold, wrong codepage — from a previous print job.
  bytes.addAll(g.reset());

  // Logo (optional, centered)
  final logo = input.logo;
  if (logo != null) {
    bytes.addAll(g.rawBytes(_rasterBytes(logo)));
    bytes.addAll(g.feed(1));
  }

  // Header — bold barbershop name, no double sizing (breaks on cheap
  // firmwares by dragging the whole block into double-width sticky mode).
  if (input.printBarbershopName) {
    bytes.addAll(g.text(
      _ascii(input.barbershopName),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(g.feed(1));
  }

  final ticketShort = input.ticketId.length >= 8
      ? input.ticketId.substring(0, 8).toUpperCase()
      : input.ticketId.toUpperCase();

  bytes.addAll(g.text('Ticket: $ticketShort'));
  bytes.addAll(g.text('Fecha: ${_formatDateTime(input.createdAt)}'));
  if (input.barberName != null && input.barberName!.isNotEmpty) {
    bytes.addAll(g.text('Barbero: ${_ascii(input.barberName!)}'));
  }
  if (input.stationLabel != null && input.stationLabel!.isNotEmpty) {
    bytes.addAll(g.text('Silla: ${_ascii(input.stationLabel!)}'));
  }

  bytes.addAll(g.hr());

  // Line items — 12-col grid: [8 name + qty][4 subtotal right]. Column
  // positioning is absolute in ESC/POS, so wrap and alignment are perfect
  // regardless of font width.
  for (final item in input.lines) {
    final subtotal =
        _formatCurrency(double.parse(item.unitPrice) * item.quantity);
    bytes.addAll(g.row([
      PosColumn(
        text: _ascii('${item.quantity}x ${item.name}'),
        width: 8,
      ),
      PosColumn(
        text: subtotal,
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
  }

  bytes.addAll(g.hr());
  bytes.addAll(g.row([
    PosColumn(
      text: 'TOTAL',
      width: 6,
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    ),
    PosColumn(
      text: _formatCurrency(input.total),
      width: 6,
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        align: PosAlign.right,
      ),
    ),
  ]));

  bytes.addAll(g.feed(1));

  final footer = input.footer?.trim();
  if (footer != null && footer.isNotEmpty) {
    for (final line in footer.split('\n')) {
      bytes.addAll(g.text(
        _ascii(line),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
  }

  bytes.addAll(g.feed(3));
  bytes.addAll(g.cut());
  return bytes;
}

List<int> _rasterBytes(ReceiptBitmap logo) {
  // GS v 0 m xL xH yL yH d1..dk — same command the web client emits.
  final widthBytes = logo.widthDots ~/ 8;
  return [
    0x1d, 0x76, 0x30, 0x00,
    widthBytes & 0xff, (widthBytes >> 8) & 0xff,
    logo.heightDots & 0xff, (logo.heightDots >> 8) & 0xff,
    ...logo.bytes,
  ];
}

// Strip Spanish diacritics as a safety net. CP850 supports ñ/á natively but
// if the printer profile doesn't include it the codepage table falls back
// silently to CP437 and the char comes out as garbage. Better to render "a"
// than "?" or a random symbol.
String _ascii(String input) {
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
  final buf = StringBuffer();
  for (final r in input.runes) {
    final ch = String.fromCharCode(r);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

// Same C$ (Nicaragua córdoba) formatting as the web POS.
final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es_NI',
  decimalDigits: 2,
);

String _formatCurrency(dynamic value) {
  final n = value is num ? value : double.parse(value.toString());
  return 'C\$${_numberFormat.format(n)}';
}

String _formatDateTime(String iso) {
  final date = DateTime.parse(iso).toLocal();
  return DateFormat("d/M/yy, HH:mm", 'es_NI').format(date);
}
