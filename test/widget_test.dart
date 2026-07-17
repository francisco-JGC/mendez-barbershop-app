import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mendez_pos/features/printing/domain/receipt.dart';

void main() {
  // esc_pos_utils_plus loads profile JSON from bundled assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es_NI');
  });

  test('buildReceipt emits ESC/POS bytes for a simple ticket', () async {
    final bytes = await buildReceipt(ReceiptInput(
      paperSize: PaperSize.mm58,
      barbershopName: 'Mendez Barbershop',
      ticketId: 'ABCDEF01',
      createdAt: DateTime.utc(2026, 7, 17, 12, 30).toIso8601String(),
      lines: const [
        ReceiptLineItem(name: 'Corte', quantity: 1, unitPrice: '150.00'),
      ],
      total: '150.00',
      footer: 'Gracias',
    ));
    expect(bytes, isNotEmpty);
    // Should contain the ESC @ (init) command somewhere in the header.
    for (var i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0x1b && bytes[i + 1] == 0x40) return;
    }
    fail('ESC/POS init command not found in output');
  });

  test('buildReceipt strips Spanish accents so receipts stay ASCII-safe',
      () async {
    final bytes = await buildReceipt(ReceiptInput(
      paperSize: PaperSize.mm58,
      barbershopName: 'Peluqueria Ñandú',
      ticketId: 'AAAAAAAA',
      createdAt: DateTime.utc(2026, 7, 17, 12, 30).toIso8601String(),
      lines: const [
        ReceiptLineItem(name: 'Corte niño', quantity: 1, unitPrice: '100.00'),
      ],
      total: '100.00',
    ));
    // The bytes stream will contain non-printable ESC sequences plus text.
    // We only assert the diacritic-free forms are present somewhere.
    final asString = String.fromCharCodes(bytes.where((b) => b >= 0x20 && b < 0x7f));
    expect(asString, contains('Nandu'));
    expect(asString, contains('Corte nino'));
  });
}
