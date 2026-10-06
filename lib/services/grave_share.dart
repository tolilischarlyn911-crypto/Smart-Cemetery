import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cemetery_models.dart';
import 'google_maps_directions.dart';

String graveShareText(Grave grave, {bool sampleLocation = false}) {
  final name = grave.name.isEmpty ? 'Grave location' : grave.name;
  return [
    name,
    grave.location,
    if (sampleLocation)
      'Illustrative demo location. This does not lead to a real grave.',
    if (grave.hasValidCoordinates)
      'Google Maps walking directions: ${googleMapsWalkingDirections(grave)}'
    else
      'Ask the cemetery office for the exact grave location.',
  ].join('\n');
}

Future<void> shareGrave(
  BuildContext context,
  Grave grave, {
  bool sampleLocation = false,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: graveShareText(grave, sampleLocation: sampleLocation),
        subject: grave.name.isEmpty ? grave.location : grave.name,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share grave details: $error')),
      );
    }
  }
}
