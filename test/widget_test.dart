import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mendez_pos/features/printing/domain/escpos_builder.dart';
import 'package:mendez_pos/features/printing/domain/receipt.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_NI');
  });

  test('twoColumns pads to exact width', () {
    final r = twoColumns('Corte', 'C\$150.00', 22);
    expect(r.length, 22);
    expect(r.startsWith('Corte'), isTrue);
    expect(r.endsWith('C\$150.00'), isTrue);
  });

  test('twoColumns clips left when too long', () {
    final r = twoColumns('x' * 30, 'C\$1.00', 22);
    expect(r.length, 22);
    expect(r.endsWith('C\$1.00'), isTrue);
  });

  test('ReceiptBuilder emits reset sequence starting with ESC @', () {
    final bytes = ReceiptBuilder().build();
    expect(bytes[0], 0x1b);
    expect(bytes[1], 0x40);
  });

  test('buildReceipt produces non-empty output ending with a cut', () {
    final bytes = buildReceipt(ReceiptInput(
      charsPerLine: 22,
      barbershopName: 'Mendez',
      ticketId: 'ABCDEF12',
      createdAt: DateTime.utc(2026, 7, 17, 12, 0).toIso8601String(),
      lines: const [
        ReceiptLineItem(
            name: 'Corte clasico largo', quantity: 2, unitPrice: '150.00'),
      ],
      total: '300.00',
    ));
    expect(bytes, isNotEmpty);
    // Should end with GS V 0 (full cut).
    expect(bytes.sublist(bytes.length - 3), [0x1d, 0x56, 0x00]);
  });
}
