import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/grave_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grave = Grave(
    id: 'pedro',
    name: 'Pedro Dela Cruz',
    block: '12',
    lot: '45',
    number: '3',
    mapRow: 0,
    mapColumn: 0,
    latitude: 14.6327,
    longitude: 120.9897,
  );

  test('shared demo grave includes location and a clear sample warning', () {
    final text = graveShareText(grave, sampleLocation: true);
    expect(text, contains('Pedro Dela Cruz'));
    expect(text, contains('Block 12 · Lot 45 · Grave 3'));
    expect(text, contains('Illustrative demo location'));
    expect(text, contains('destination=14.6327%2C120.9897'));
  });

  test('a grave without a pin does not share a misleading map link', () {
    final text = graveShareText(
      const Grave(
        id: 'unpinned',
        name: 'Unpinned',
        block: '1',
        lot: '2',
        number: '3',
        mapRow: 0,
        mapColumn: 0,
      ),
    );
    expect(text, contains('Ask the cemetery office'));
    expect(text, isNot(contains('https://')));
  });
}
