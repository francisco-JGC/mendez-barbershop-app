import 'package:flutter_test/flutter_test.dart';
import 'package:mendez_pos/features/printing/domain/escpos_builder.dart';

void main() {
  group('twoColumns', () {
    test('pads left+right to exact width', () {
      final result = twoColumns('Corte', 'C\$150.00', 32);
      expect(result.length, 32);
      expect(result.startsWith('Corte'), isTrue);
      expect(result.endsWith('C\$150.00'), isTrue);
    });

    test('clips left when it overflows', () {
      final long = 'x' * 40;
      final result = twoColumns(long, 'C\$1.00', 32);
      expect(result.length, 32);
      expect(result.endsWith('C\$1.00'), isTrue);
    });
  });

  test('ReceiptBuilder emits initialization sequence', () {
    final bytes = ReceiptBuilder().build();
    expect(bytes.length, 2);
    expect(bytes[0], 0x1b);
    expect(bytes[1], 0x40);
  });

  test('ReceiptBuilder strips diacritics from Spanish text', () {
    final bytes = ReceiptBuilder().text('Ñoño áéíóú').build();
    // Skip the leading ESC @ init bytes.
    final rendered =
        String.fromCharCodes(bytes.sublist(2));
    expect(rendered, 'Nono aeiou');
  });
}
