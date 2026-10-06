import 'package:capstone_project/models/cemetery_models.dart';
import 'package:capstone_project/services/google_maps_directions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('Google Maps URL requests walking navigation to grave coordinates', () {
    const grave = Grave(
      id: 'grave-1', name: 'Test', block: '12', lot: '45', number: '3',
      mapRow: 0, mapColumn: 0, latitude: 14.6327, longitude: 120.9897,
    );
    final url = googleMapsWalkingDirections(grave,
      origin: const LatLng(14.6323, 120.9894));
    expect(url.host, 'www.google.com');
    expect(url.path, '/maps/dir/');
    expect(url.queryParameters, {
      'api': '1',
      'origin': '14.6323,120.9894',
      'destination': '14.6327,120.9897',
      'travelmode': 'walking',
      'dir_action': 'navigate',
    });
  });

  test('missing grave coordinates cannot start navigation', () {
    const grave = Grave(
      id: 'grave-1', name: 'Test', block: '12', lot: '45', number: '3',
      mapRow: 0, mapColumn: 0,
    );
    expect(() => googleMapsWalkingDirections(grave), throwsArgumentError);
  });
}
