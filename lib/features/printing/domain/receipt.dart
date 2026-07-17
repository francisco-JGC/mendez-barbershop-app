import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'escpos_builder.dart';

/// Bitmap primed for [ReceiptBuilder.rasterImage].
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
    this.barberName,
    this.stationLabel,
    this.footer,
    this.logo,
    this.printBarbershopName = true,
    this.width = 32,
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
  final int width;
}

/// 1:1 port of `mendez-barbershop-client/src/lib/receipt.ts::buildReceipt`.
Uint8List buildReceipt(ReceiptInput input) {
  final receipt = ReceiptBuilder().align(TextAlign.center);

  final logo = input.logo;
  if (logo != null) {
    receipt.rasterImage(logo.widthDots, logo.heightDots, logo.bytes).newline();
  }

  if (input.printBarbershopName) {
    receipt
        .bold(true)
        .doubleHeight(true)
        .line(input.barbershopName)
        .doubleHeight(false)
        .bold(false)
        .newline();
  }

  final ticketShort =
      input.ticketId.length >= 8 ? input.ticketId.substring(0, 8) : input.ticketId;

  receipt
      .align(TextAlign.left)
      .line('Ticket: ${ticketShort.toUpperCase()}')
      .line('Fecha: ${_formatDateTime(input.createdAt)}');

  if (input.barberName != null && input.barberName!.isNotEmpty) {
    receipt.line('Barbero: ${input.barberName}');
  }
  if (input.stationLabel != null && input.stationLabel!.isNotEmpty) {
    receipt.line('Silla: ${input.stationLabel}');
  }

  receipt.divider(input.width);

  for (final item in input.lines) {
    final subtotal =
        _formatCurrency(double.parse(item.unitPrice) * item.quantity);
    receipt.line(twoColumns(
      '${item.quantity}x ${item.name}',
      subtotal,
      input.width,
    ));
  }

  receipt
      .divider(input.width)
      .bold(true)
      .line(twoColumns('TOTAL', _formatCurrency(input.total), input.width))
      .bold(false)
      .newline()
      .align(TextAlign.center);

  final footer = input.footer?.trim();
  if (footer != null && footer.isNotEmpty) {
    for (final footerLine in footer.split('\n')) {
      receipt.line(footerLine);
    }
  }

  receipt.newline(3).cut();
  return receipt.build();
}

// The web client uses `C$` (córdoba nicaragüense) and es-NI number formatting.
// Kept identical here so both POS terminals print the same ticket string.
final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es_NI',
  decimalDigits: 2,
);

String _formatCurrency(dynamic value) {
  final n = value is num ? value : double.parse(value.toString());
  return 'C\$${_numberFormat.format(n)}';
}

/// Mirrors `formatDateTime` in the web (`toLocaleString('es-NI', {dateStyle:'short', timeStyle:'short'})`).
String _formatDateTime(String iso) {
  final date = DateTime.parse(iso).toLocal();
  // es-NI short date: d/M/yy; short time: HH:mm (24h).
  return DateFormat("d/M/yy, HH:mm", 'es_NI').format(date);
}
