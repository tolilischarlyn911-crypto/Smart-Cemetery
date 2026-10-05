import 'package:capstone_project/services/burial_date_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grave dates must be real YYYY-MM-DD calendar days', () {
    expect(parseBurialDate('2024-02-29'), DateTime(2024, 2, 29));
    for (final value in [
      '2023-02-29',
      '2024-02-31',
      '2024-13-01',
      '2024-00-15',
      '2024-01-00',
      '2024-1-1',
      '0000-01-01',
    ]) {
      expect(parseBurialDate(value), isNull, reason: value);
    }
  });

  test('birth, death, and burial dates stay in chronological order', () {
    expect(
      burialDateOrderError(born: DateTime(2020), died: DateTime(2019)),
      contains('Birth date'),
    );
    expect(
      burialDateOrderError(
        died: DateTime(2020, 3, 5),
        buriedAt: DateTime(2020, 3, 4),
      ),
      contains('Burial date'),
    );
    expect(
      burialDateOrderError(born: DateTime(2020), buriedAt: DateTime(2019)),
      contains('Burial date'),
    );
    expect(
      burialDateOrderError(
        born: DateTime(1940),
        died: DateTime(2020, 3, 3),
        buriedAt: DateTime(2020, 3, 5),
      ),
      isNull,
    );
  });
}
