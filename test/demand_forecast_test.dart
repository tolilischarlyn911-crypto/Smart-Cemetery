import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/demand_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

Grave plot(int index, {DateTime? buriedAt}) => Grave(
  id: 'plot-$index', name: buriedAt == null ? '' : 'Person $index',
  block: '1', lot: '$index', number: '1', mapRow: index ~/ 5,
  mapColumn: index % 5, status: buriedAt == null ? 'available' : 'occupied',
  buriedAt: buriedAt,
);

void main() {
  final today = DateTime(2026, 10, 4);

  test('sparse history has no forecast', () {
    final graves = [
      for (var index = 0; index < 40; index++)
        plot(index, buriedAt: index < 3 ? DateTime(2026, index + 1) : null),
    ];
    expect(forecastDemand(graves, asOf: today), isNull);
  });

  test('dated history produces bounded, increasing occupancy estimates', () {
    final graves = [
      for (var index = 0; index < 40; index++)
        plot(index, buriedAt: index < 12 ? DateTime(2025, 10 + index) : null),
    ];
    final forecast = forecastDemand(graves, asOf: today)!;
    expect(forecast.observedBurials, 12);
    expect(forecast.occupiedNow, 12);
    expect(forecast.yearly, hasLength(5));
    expect(forecast.yearly.first.occupancy, greaterThan(12 / 40));
    for (var index = 1; index < forecast.yearly.length; index++) {
      expect(forecast.yearly[index].occupancy,
        greaterThanOrEqualTo(forecast.yearly[index - 1].occupancy));
      expect(forecast.yearly[index].occupancy, lessThanOrEqualTo(1));
    }
  });
}
