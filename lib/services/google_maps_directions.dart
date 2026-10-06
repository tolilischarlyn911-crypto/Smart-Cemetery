import '../models/cemetery_models.dart';
import 'package:latlong2/latlong.dart';

/// Opens Google Maps with a walking route from the user's current location.
/// Google Maps decides whether to start navigation or show a route preview.
Uri googleMapsWalkingDirections(Grave grave, {LatLng? origin}) {
  final latitude = grave.latitude;
  final longitude = grave.longitude;
  if (!grave.hasValidCoordinates) {
    throw ArgumentError('This grave needs valid coordinates.');
  }
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (origin != null) 'origin': '${origin.latitude},${origin.longitude}',
    'destination': '$latitude,$longitude',
    'travelmode': 'walking',
    'dir_action': 'navigate',
  });
}
