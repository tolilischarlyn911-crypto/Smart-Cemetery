import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/cemetery_store.dart';
import '../../services/firebase_setup.dart';

class GravePinPicker extends StatefulWidget {
  const GravePinPicker({
    super.key,
    required this.title,
    required this.center,
    this.initialPoint,
    this.initialZoom = 18,
  });

  final String title;
  final LatLng center;
  final LatLng? initialPoint;
  final double initialZoom;

  static Future<LatLng?> pick(
    BuildContext context, {
    required String title,
    required LatLng center,
    LatLng? initialPoint,
    double initialZoom = 18,
  }) => showDialog<LatLng>(
    context: context,
    builder: (_) => GravePinPicker(
      title: title,
      center: center,
      initialPoint: initialPoint,
      initialZoom: initialZoom,
    ),
  );

  @override
  State<GravePinPicker> createState() => _GravePinPickerState();
}

class _GravePinPickerState extends State<GravePinPicker> {
  static const _tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  final MapController _controller = MapController();
  final GlobalKey _mapKey = GlobalKey();
  late LatLng? _point = widget.initialPoint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final demo = CemeteryStore.instance.isDemo || FirebaseSetup.useEmulators;
    return Dialog(
      child: SizedBox(
        width: math.min(size.width - 32, 800),
        height: math.min(size.height - 32, 650),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel map selection',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Drag the map to the location, then tap or drag the pin into place.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    key: _mapKey,
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: _point ?? widget.center,
                      initialZoom: widget.initialZoom,
                      minZoom: 4,
                      maxZoom: 20,
                      onTap: (_, point) => setState(() => _point = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _tileUrl,
                        userAgentPackageName: 'org.smartcemetery.capstone',
                      ),
                      if (_point != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _point!,
                              width: 48,
                              height: 48,
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerMove: (event) {
                                  final box =
                                      _mapKey.currentContext?.findRenderObject()
                                          as RenderBox?;
                                  if (box == null) return;
                                  final offset = box.globalToLocal(
                                    event.position,
                                  );
                                  setState(
                                    () => _point = _controller.camera
                                        .screenOffsetToLatLng(offset),
                                  );
                                },
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Icon(
                                    Icons.add_location,
                                    size: 42,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (demo)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Chip(label: Text('Illustrative demo map')),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        _zoomButton(Icons.add, 'Zoom in', 1),
                        const SizedBox(height: 6),
                        _zoomButton(Icons.remove, 'Zoom out', -1),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.95),
                      child: InkWell(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _point == null
                          ? 'No pin selected'
                          : '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _point == null
                        ? null
                        : () => Navigator.pop(context, _point),
                    icon: const Icon(Icons.check),
                    label: const Text('Use this pin'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomButton(IconData icon, String tooltip, double change) => Material(
    elevation: 2,
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    child: IconButton(
      tooltip: tooltip,
      onPressed: () {
        final zoom = (_controller.camera.zoom + change).clamp(4.0, 20.0);
        _controller.move(_controller.camera.center, zoom);
      },
      icon: Icon(icon),
    ),
  );
}
