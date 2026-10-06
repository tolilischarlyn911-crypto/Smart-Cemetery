import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/cemetery_store.dart';
import '../models/cemetery_models.dart';
import '../services/firebase_setup.dart';
import '../services/google_maps_directions.dart';
import '../services/grave_share.dart';
import '../services/photo_service.dart';
import '../widgets/grave_map_marker.dart';
import 'grave_details_screen.dart';

class MapNavigationScreen extends StatefulWidget {
  final String? graveId;
  final bool adminMode;
  const MapNavigationScreen({super.key, this.graveId, this.adminMode = false});

  @override
  State<MapNavigationScreen> createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  static const _tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  final MapController _mapController = MapController();
  google.GoogleMapController? _googleMapController;
  double _googleZoom = 18;
  google.LatLng? _googleCenter;
  String? _selectedId;
  LatLng? _devicePosition;
  LatLng? _placement;
  bool _locating = false;
  String? _requestedMarkerStyle;
  Map<String, google.BitmapDescriptor> _tombstoneIcons = {};

  bool get _usingSampleMap =>
      CemeteryStore.instance.isDemo || FirebaseSetup.useEmulators;

  bool get _usingGoogleMap =>
      const bool.fromEnvironment('GOOGLE_MAPS_ENABLED') &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _selectedId = widget.graveId;
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _point(Grave? grave) => grave?.hasValidCoordinates != true
      ? null
      : LatLng(grave!.latitude!, grave.longitude!);

  Color _statusColor(String status) => status == 'occupied'
      ? Colors.red
      : status == 'available'
      ? Colors.green
      : Colors.amber.shade800;

  void _ensureNativeMarkerIcons(String style) {
    if (!_usingGoogleMap ||
        style != 'tombstone' ||
        _requestedMarkerStyle == style) {
      return;
    }
    _requestedMarkerStyle = style;
    Future.wait([
      GraveMapMarker.png(Colors.red),
      GraveMapMarker.png(Colors.green),
      GraveMapMarker.png(Colors.amber.shade800),
    ]).then((images) {
      if (!mounted || _requestedMarkerStyle != style) return;
      setState(() {
        _tombstoneIcons = {
          'occupied': google.BitmapDescriptor.bytes(
            images[0],
            width: 40,
            height: 44,
          ),
          'available': google.BitmapDescriptor.bytes(
            images[1],
            width: 40,
            height: 44,
          ),
          'reserved': google.BitmapDescriptor.bytes(
            images[2],
            width: 40,
            height: 44,
          ),
        };
      });
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _devicePosition = point);
      _moveMap(point, 18);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _startNavigation(Grave grave) async {
    if (kIsWeb) {
      // Keep this launch in the original click gesture. Browsers may block a
      // new tab after an awaited location request or confirmation dialog.
      await _openGoogleMaps(grave);
      return;
    }
    if (_usingSampleMap) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sample grave location'),
          content: const Text(
            'This preview uses sample coordinates. Google Maps can show a walking route to that sample point, but it cannot guide you to a real grave until an administrator saves its exact location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OPEN GOOGLE MAPS'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    if (_devicePosition == null) {
      await _locate();
      if (!mounted) return;
    }
    await _openGoogleMaps(grave);
  }

  Future<void> _openGoogleMaps(Grave grave) async {
    try {
      final opened = await launchUrl(
        googleMapsWalkingDirections(grave, origin: _devicePosition),
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps on this device.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _selectGrave(Grave grave) {
    setState(() {
      _selectedId = grave.id;
      _placement = null;
    });
    final point = _point(grave);
    if (point != null) {
      _moveMap(
        point,
        _usingGoogleMap ? _googleZoom : _mapController.camera.zoom,
      );
    }
  }

  void _moveMap(LatLng point, double zoom) {
    if (_usingGoogleMap) {
      _googleZoom = zoom.clamp(4, 20);
      _googleCenter = google.LatLng(point.latitude, point.longitude);
      _googleMapController?.animateCamera(
        google.CameraUpdate.newLatLngZoom(_googleCenter!, _googleZoom),
      );
    } else {
      _mapController.move(point, zoom);
    }
  }

  void _zoomMap(double step) {
    if (_usingGoogleMap) {
      final center = _googleCenter;
      if (center == null) return;
      _moveMap(LatLng(center.latitude, center.longitude), _googleZoom + step);
    } else {
      _mapController.move(
        _mapController.camera.center,
        _mapController.camera.zoom + step,
      );
    }
  }

  Future<void> _chooseGrave(CemeteryStore store) async {
    var query = '';
    String? blockFilter;
    var unpinnedOnly = false;
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final blocks =
              store.graves
                  .map((grave) => grave.block)
                  .where((block) => block.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final filtered = store.graves.where((grave) {
            final text = query.trim().toLowerCase();
            return (blockFilter == null || grave.block == blockFilter) &&
                (!unpinnedOnly || !grave.hasValidCoordinates) &&
                (text.isEmpty ||
                    grave.name.toLowerCase().contains(text) ||
                    grave.location.toLowerCase().contains(text) ||
                    grave.id.toLowerCase().contains(text));
          }).toList();
          final matches = filtered.take(50).toList();
          return AlertDialog(
            title: const Text('Select a grave or plot'),
            content: SizedBox(
              width: 420,
              height: 500,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search name, block, or lot',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => refresh(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: blockFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Block',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All blocks'),
                            ),
                            for (final block in blocks)
                              DropdownMenuItem<String?>(
                                value: block,
                                child: Text('Block $block'),
                              ),
                          ],
                          onChanged: (value) =>
                              refresh(() => blockFilter = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Needs pin'),
                        selected: unpinnedOnly,
                        selectedColor: const Color(0xFFE4F2E8),
                        side: const BorderSide(color: Color(0xFF0B4A2D)),
                        onSelected: (value) =>
                            refresh(() => unpinnedOnly = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      filtered.length > matches.length
                          ? '${filtered.length} matching plots · showing first ${matches.length}'
                          : '${filtered.length} matching plots',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('No matching plots.'))
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final grave = matches[index];
                              return ListTile(
                                title: Text(
                                  grave.name.isEmpty
                                      ? grave.location
                                      : grave.name,
                                ),
                                subtitle: Text(
                                  '${grave.location} · ${grave.status}${grave.hasValidCoordinates ? '' : ' · Needs pin'}',
                                ),
                                onTap: () =>
                                    Navigator.pop(dialogContext, grave.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    if (id == null || !mounted) return;
    final grave = store.graveById(id);
    if (grave != null) _selectGrave(grave);
  }

  Future<void> _savePlacement(CemeteryStore store, Grave grave) async {
    final point = _placement;
    if (point == null) return;
    try {
      await store.saveGrave(
        grave.copyWithLocation(point.latitude, point.longitude),
      );
      if (mounted) {
        setState(() => _placement = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Grave pin saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save grave pin: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CemeteryStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final markerStyle = '${store.settings['gravePinStyle'] ?? 'tombstone'}';
        _ensureNativeMarkerIcons(markerStyle);
        Grave? selectedGrave = _selectedId == null
            ? null
            : store.graveById(_selectedId!);
        if (selectedGrave == null && !widget.adminMode) {
          for (final grave in store.graves) {
            if (grave.status == 'occupied' && _point(grave) != null) {
              selectedGrave = grave;
              break;
            }
          }
        }
        final selected = selectedGrave;
        final markers = store.graves
            .where(
              (grave) =>
                  _point(grave) != null &&
                  (widget.adminMode || grave.status == 'occupied'),
            )
            .toList();
        final target = _point(selected);
        final configuredCenter = store.mapCenter;
        final center =
            target ??
            (markers.isEmpty ? null : _point(markers.first)) ??
            (!widget.adminMode || configuredCenter == null
                ? null
                : LatLng(
                    configuredCenter.latitude,
                    configuredCenter.longitude,
                  ));
        if (center == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.adminMode ? 'Map Management' : 'Map & Navigation',
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.adminMode
                      ? 'Set the cemetery map center in System Settings, or add a grave coordinate in Grave Management. Then select a plot here and tap its exact map location.'
                      : 'No occupied graves with map coordinates are available yet. Ask the cemetery office for the grave location.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final origin = _devicePosition;
        final distance = target == null || origin == null
            ? null
            : const Distance().as(LengthUnit.Meter, origin, target).round();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.adminMode ? 'Map Management' : 'Map & Navigation',
            ),
            actions: [
              if (!widget.adminMode && selected != null)
                Builder(
                  builder: (shareContext) => IconButton(
                    tooltip: 'Share grave location',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => shareGrave(
                      shareContext,
                      selected,
                      sampleLocation: _usingSampleMap,
                    ),
                  ),
                ),
            ],
          ),
          body: Stack(
            children: [
              ExcludeSemantics(
                excluding: kIsWeb && widget.adminMode,
                child: _usingGoogleMap
                    ? google.GoogleMap(
                        initialCameraPosition: google.CameraPosition(
                          target: google.LatLng(
                            center.latitude,
                            center.longitude,
                          ),
                          zoom: 18,
                        ),
                        onMapCreated: (controller) {
                          _googleMapController = controller;
                          _googleCenter = google.LatLng(
                            center.latitude,
                            center.longitude,
                          );
                        },
                        onCameraMove: (position) {
                          _googleCenter = position.target;
                          _googleZoom = position.zoom;
                        },
                        onTap: widget.adminMode
                            ? (point) => setState(
                                () => _placement = LatLng(
                                  point.latitude,
                                  point.longitude,
                                ),
                              )
                            : null,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        markers: {
                          for (final grave in markers)
                            google.Marker(
                              markerId: google.MarkerId(grave.id),
                              position: google.LatLng(
                                grave.latitude!,
                                grave.longitude!,
                              ),
                              infoWindow: google.InfoWindow(
                                title: grave.name.isEmpty
                                    ? grave.location
                                    : grave.name,
                                snippet: grave.location,
                              ),
                              icon:
                                  markerStyle == 'tombstone' &&
                                      _tombstoneIcons.containsKey(grave.status)
                                  ? _tombstoneIcons[grave.status]!
                                  : google
                                        .BitmapDescriptor.defaultMarkerWithHue(
                                      grave.status == 'occupied'
                                          ? google.BitmapDescriptor.hueRed
                                          : grave.status == 'available'
                                          ? google.BitmapDescriptor.hueGreen
                                          : google.BitmapDescriptor.hueOrange,
                                    ),
                              onTap: () => _selectGrave(grave),
                            ),
                          if (origin != null)
                            google.Marker(
                              markerId: const google.MarkerId(
                                'device-position',
                              ),
                              position: google.LatLng(
                                origin.latitude,
                                origin.longitude,
                              ),
                              icon:
                                  google.BitmapDescriptor.defaultMarkerWithHue(
                                    google.BitmapDescriptor.hueAzure,
                                  ),
                            ),
                          if (_placement != null)
                            google.Marker(
                              markerId: const google.MarkerId('proposed-pin'),
                              position: google.LatLng(
                                _placement!.latitude,
                                _placement!.longitude,
                              ),
                              icon:
                                  google.BitmapDescriptor.defaultMarkerWithHue(
                                    google.BitmapDescriptor.hueViolet,
                                  ),
                            ),
                        },
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 18,
                          minZoom: 4,
                          maxZoom: 20,
                          onTap: widget.adminMode
                              ? (_, point) => setState(() => _placement = point)
                              : null,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _tileUrl,
                            userAgentPackageName: 'org.smartcemetery.capstone',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final grave in markers)
                                Marker(
                                  point: _point(grave)!,
                                  width: 52,
                                  height: 52,
                                  child: IconButton(
                                    tooltip: grave.name.isEmpty
                                        ? grave.location
                                        : grave.name,
                                    onPressed: () => _selectGrave(grave),
                                    icon: markerStyle == 'tombstone'
                                        ? GraveMapMarker(
                                            color: _statusColor(grave.status),
                                            size: selected?.id == grave.id
                                                ? 42
                                                : 36,
                                          )
                                        : Icon(
                                            Icons.location_pin,
                                            size: selected?.id == grave.id
                                                ? 44
                                                : 36,
                                            color: _statusColor(grave.status),
                                          ),
                                  ),
                                ),
                              if (origin != null)
                                Marker(
                                  point: origin,
                                  width: 48,
                                  height: 48,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                              if (_placement != null)
                                Marker(
                                  point: _placement!,
                                  width: 48,
                                  height: 48,
                                  child: const Icon(
                                    Icons.add_location,
                                    color: Colors.purple,
                                    size: 40,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
              if (_usingSampleMap)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Chip(
                    label: const Text('Illustrative demo map'),
                    backgroundColor: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              if (widget.adminMode && markers.isEmpty)
                const Positioned(
                  top: 94,
                  left: 12,
                  right: 72,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'No grave pins yet. Select a plot below, then tap its location to place the first pin.',
                      ),
                    ),
                  ),
                ),
              if (!_usingGoogleMap)
                Positioned(
                  top: 52,
                  left: 12,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    child: InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _mapButton(Icons.add, 'Zoom in', () => _zoomMap(1)),
                    const SizedBox(height: 8),
                    _mapButton(Icons.remove, 'Zoom out', () => _zoomMap(-1)),
                    const SizedBox(height: 8),
                    _mapButton(
                      Icons.my_location,
                      'My location',
                      _locating ? null : _locate,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 76,
                                height: 82,
                                child: _graveThumbnail(
                                  selected,
                                  _usingSampleMap,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selected == null
                                        ? 'Select a grave marker'
                                        : selected.name.isEmpty
                                        ? 'Plot ${selected.lot}'
                                        : selected.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if (selected != null)
                                    Text(
                                      selected.location,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (distance != null && !widget.adminMode)
                                    Text(
                                      'About $distance m in a straight line',
                                      style: const TextStyle(
                                        color: Color(0xFF1B4D2E),
                                      ),
                                    ),
                                  if (widget.adminMode && target != null)
                                    Text(
                                      'Current pin: ${target.latitude.toStringAsFixed(6)}, ${target.longitude.toStringAsFixed(6)}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.adminMode) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _mapLegendItem(
                                'Occupied',
                                Colors.red,
                                markerStyle,
                              ),
                              _mapLegendItem(
                                'Reserved',
                                Colors.amber.shade800,
                                markerStyle,
                              ),
                              _mapLegendItem(
                                'Available',
                                Colors.green,
                                markerStyle,
                              ),
                              _mapLegendItem(
                                'New pin',
                                Colors.purple,
                                markerStyle,
                              ),
                              _mapLegendItem('You', Colors.blue, markerStyle),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _chooseGrave(store),
                            icon: const Icon(Icons.search),
                            label: Text(
                              selected == null
                                  ? 'SELECT GRAVE OR PLOT'
                                  : 'CHANGE GRAVE OR PLOT',
                            ),
                          ),
                          const Text(
                            'Select a plot, then tap its exact location on the map.',
                          ),
                          if (_placement != null)
                            Text(
                              'New pin: ${_placement!.latitude.toStringAsFixed(6)}, ${_placement!.longitude.toStringAsFixed(6)}',
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: selected == null || _placement == null
                                ? null
                                : () => _savePlacement(store, selected),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('SAVE PIN TO SELECTED PLOT'),
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Walking directions open in Google Maps. Cemetery paths may not appear in its map data.',
                            ),
                          ),
                          if (_usingSampleMap && kIsWeb)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Preview uses sample grave coordinates. The Google Maps route does not lead to a real grave.',
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed:
                                selected == null ||
                                    target == null ||
                                    _locating ||
                                    selected.status != 'occupied'
                                ? null
                                : () => _startNavigation(selected),
                            icon: const Icon(Icons.route),
                            label: const Text('START NAVIGATION'),
                          ),
                        ],
                        if (selected?.status == 'occupied' && !widget.adminMode)
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GraveDetailsScreen(graveId: selected!.id),
                              ),
                            ),
                            child: const Text('VIEW MEMORIAL'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _graveThumbnail(Grave? grave, bool demo) {
    if (grave == null || grave.status != 'occupied') {
      return Container(
        color: Colors.green.shade50,
        child: const Icon(
          Icons.grass_outlined,
          color: Color(0xFF1B4D2E),
          size: 32,
        ),
      );
    }
    final source =
        grave.tombPhotoUrl ??
        (grave.photos.isNotEmpty ? grave.photos.first : null);
    if (source == null && demo) {
      return Image.asset('assets/images/grave_sample.png', fit: BoxFit.cover);
    }
    if (source == null) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.photo_outlined, size: 32),
      );
    }
    final provider = PhotoService.provider(source);
    if (provider == null) return const Icon(Icons.broken_image_outlined);
    return Image(
      image: provider,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }

  Widget _mapLegendItem(String label, Color color, String markerStyle) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (markerStyle == 'tombstone' &&
          (label == 'Occupied' || label == 'Reserved' || label == 'Available'))
        GraveMapMarker(color: color, size: 17)
      else
        Icon(
          label == 'You' ? Icons.my_location : Icons.location_pin,
          size: 18,
          color: color,
        ),
      const SizedBox(width: 2),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _mapButton(IconData icon, String tooltip, VoidCallback? onPressed) =>
      Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      );
}
