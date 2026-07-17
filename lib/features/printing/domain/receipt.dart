import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'escpos_builder.dart';

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
    required this.charsPerLine,
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
  final int charsPerLine;
}

/// Builds a receipt with a manually-controlled character width. All layout is
/// done by concatenating strings that are guaranteed to be `<= charsPerLine`,
/// so the printer's own wrap logic is never triggered.
List<int> buildReceipt(ReceiptInput input) {
  final w = input.charsPerLine;
  final b = ReceiptBuilder();

  // Logo (optional, centered)
  final logo = input.logo;
  if (logo != null) {
    b.align(TextAlign.center);
    b.rasterImage(logo.widthDots, logo.heightDots, logo.bytes);
    b.newline();
  }

  // Header — bold barbershop name centered. No double-height/width: cheap
  // firmwares latch on to it and every subsequent line ends up double-sized.
  if (input.printBarbershopName) {
    b.align(TextAlign.center).bold(true);
    for (final chunk in _wrap(input.barbershopName, w)) {
      b.line(chunk);
    }
    b.bold(false).newline();
  }

  b.align(TextAlign.left);
  final ticketShort = input.ticketId.length >= 8
      ? input.ticketId.substring(0, 8).toUpperCase()
      : input.ticketId.toUpperCase();

  _writeLabelValue(b, 'Ticket:', ticketShort, w);
  _writeLabelValue(b, 'Fecha:', _formatDateTime(input.createdAt), w);
  if (input.barberName != null && input.barberName!.isNotEmpty) {
    _writeLabelValue(b, 'Barbero:', input.barberName!, w);
  }
  if (input.stationLabel != null && input.stationLabel!.isNotEmpty) {
    _writeLabelValue(b, 'Silla:', input.stationLabel!, w);
  }

  b.divider(w);

  for (final item in input.lines) {
    final subtotal =
        _formatCurrency(double.parse(item.unitPrice) * item.quantity);
    final label = '${item.quantity}x ${item.name}';
    // If the label is very long we render it on its own line so the price
    // stays flush right.
    if (label.length + 1 + subtotal.length > w) {
      for (final chunk in _wrap(label, w)) {
        b.line(chunk);
      }
      b.line(twoColumns('', subtotal, w));
    } else {
      b.line(twoColumns(label, subtotal, w));
    }
  }

  b.divider(w);
  b.bold(true).line(twoColumns('TOTAL', _formatCurrency(input.total), w));
  b.bold(false);
  b.newline();

  final footer = input.footer?.trim();
  if (footer != null && footer.isNotEmpty) {
    b.align(TextAlign.center);
    for (final rawLine in footer.split('\n')) {
      for (final chunk in _wrap(rawLine, w)) {
        b.line(chunk);
      }
    }
  }

  b.newline(3);
  b.cut();
  return b.build();
}

/// Writes `Label value` on a single line if it fits, else label on its own
/// line and value below indented. Keeps info readable no matter how narrow
/// the paper.
void _writeLabelValue(ReceiptBuilder b, String label, String value, int width) {
  final combined = '$label $value';
  if (combined.length <= width) {
    b.line(combined);
  } else {
    b.line(label);
    for (final chunk in _wrap(value, width)) {
      b.line(chunk);
    }
  }
}

/// Word-wraps [text] to lines of at most [width] characters. Very simple:
/// splits on spaces, only hard-breaks tokens longer than [width].
List<String> _wrap(String text, int width) {
  if (text.length <= width) return [text];
  final words = text.split(' ');
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    if (word.length > width) {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
      for (var i = 0; i < word.length; i += width) {
        final end = (i + width) > word.length ? word.length : i + width;
        final piece = word.substring(i, end);
        if (i + width >= word.length) {
          current = piece;
        } else {
          lines.add(piece);
        }
      }
    } else if (current.isEmpty) {
      current = word;
    } else if (current.length + 1 + word.length <= width) {
      current = '$current $word';
    } else {
      lines.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

// C$ (Nicaragua córdoba) formatting mirrors the web POS.
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
