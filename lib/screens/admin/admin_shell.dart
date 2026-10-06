import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:latlong2/latlong.dart' as geo;

import '../../data/cemetery_store.dart';
import '../../models/cemetery_models.dart';
import '../../services/backup_service.dart';
import '../../services/burial_date_validation.dart';
import '../../services/demand_forecast.dart';
import '../../services/photo_service.dart';
import '../../services/payment_document_service.dart';
import '../../services/report_export.dart';
import '../../services/staff_account_service.dart';
import '../map_navigation_screen.dart';
import 'grave_pin_picker.dart';

class AdminShell extends StatefulWidget {
  final VoidCallback? onLogout;
  final String role;
  const AdminShell({super.key, this.onLogout, this.role = 'admin'});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selected = 0;
  bool _backupBusy = false;
  final TextEditingController _graveSearch = TextEditingController();
  final TextEditingController _accountSearch = TextEditingController();
  String _graveStatusFilter = 'all';
  String _maintenanceStatusFilter = 'all';
  static const sections = [
    ('Dashboard', Icons.dashboard_outlined),
    ('Burial Records', Icons.assignment_outlined),
    ('Grave Management', Icons.grass_outlined),
    ('Map Management', Icons.map_outlined),
    ('Payments & Leases', Icons.payments_outlined),
    ('Maintenance', Icons.handyman_outlined),
    ('Reports & Analytics', Icons.bar_chart_outlined),
    ('ML Predictions', Icons.trending_up_outlined),
    ('User Management', Icons.people_outline),
    ('System Settings', Icons.settings_outlined),
  ];

  bool get _isStaff => widget.role == 'staff';
  bool _canOpenSection(int index) =>
      !_isStaff || const [1, 2, 3, 5].contains(index);

  @override
  void initState() {
    super.initState();
    if (_isStaff) selected = 1;
  }

  @override
  void dispose() {
    _graveSearch.dispose();
    _accountSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final store = CemeteryStore.instance;
    return Scaffold(
      appBar: wide ? null : AppBar(title: Text(sections[selected].$1)),
      drawer: wide
          ? null
          : Drawer(
              child: Builder(
                builder: (drawerContext) =>
                    _navigation(drawerContext: drawerContext),
              ),
            ),
      body: Row(
        children: [
          if (wide) SizedBox(width: 240, child: _navigation()),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => Column(
                children: [
                  if (store.isDemo)
                    MaterialBanner(
                      content: const Text(
                        'Local preview: changes are saved on this device only.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Local preview'),
                              content: const Text(
                                'Records are saved in this browser only. Other devices will not see these changes. Grave coordinates and photos are sample data until an administrator replaces them with verified cemetery records.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('CLOSE'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('PREVIEW'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _page(store),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation({BuildContext? drawerContext}) => Material(
    color: const Color(0xFF0B4A2D),
    child: SafeArea(
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.church_rounded, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart Cemetery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            if (_canOpenSection(i))
              ListTile(
                selected: selected == i,
                selectedTileColor: Colors.white24,
                leading: Icon(sections[i].$2, color: Colors.white),
                title: Text(
                  sections[i].$1,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() => selected = i);
                  if (drawerContext != null) Navigator.pop(drawerContext);
                },
              ),
          if (widget.onLogout != null)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
              onTap: widget.onLogout,
            ),
        ],
      ),
    ),
  );

  Widget _page(CemeteryStore store) {
    if (!_canOpenSection(selected)) {
      return const Center(
        child: Text('This section requires administrator access.'),
      );
    }
    switch (selected) {
      case 0:
        return _dashboard(store);
      case 1:
        return _graveList(store, occupiedOnly: true);
      case 2:
        return _graveList(store);
      case 3:
        return const MapNavigationScreen(adminMode: true);
      case 4:
        return _payments(store);
      case 5:
        return _maintenance(store);
      case 6:
        return _reports(store);
      case 7:
        return _predictions(store);
      case 8:
        return _staff(store);
      case 9:
        return _settings(store);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );

  Widget _dashboard(CemeteryStore store) {
    final forecast = forecastDemand(store.graves);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final statColumns = contentWidth >= 900
            ? 4
            : contentWidth >= 520
            ? 2
            : 1;
        final statWidth = (contentWidth - (statColumns - 1) * 12) / statColumns;
        final panelColumns = contentWidth >= 900 ? 2 : 1;
        final panelWidth =
            (contentWidth - (panelColumns - 1) * 16) / panelColumns;
        return ListView(
          children: [
            _heading('Dashboard', 'Welcome back, Admin!'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _stat(
                  'Total Burials',
                  store.occupiedCount,
                  Icons.person_outline,
                  const Color(0xFF187246),
                  () => setState(() => selected = 1),
                  statWidth,
                ),
                _stat(
                  'Occupied Spaces',
                  store.occupiedCount,
                  Icons.grid_on,
                  const Color(0xFFCC4545),
                  () => setState(() {
                    _graveStatusFilter = 'occupied';
                    selected = 2;
                  }),
                  statWidth,
                ),
                _stat(
                  'Available Spaces',
                  store.availableCount,
                  Icons.check_circle_outline,
                  const Color(0xFF49A65B),
                  () => setState(() {
                    _graveStatusFilter = 'available';
                    selected = 2;
                  }),
                  statWidth,
                ),
                _stat(
                  'Pending Requests',
                  store.pendingCount,
                  Icons.pending_actions,
                  const Color(0xFFDCA327),
                  () => setState(() {
                    _maintenanceStatusFilter = 'Pending';
                    selected = 5;
                  }),
                  statWidth,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _panel('Cemetery Overview', _overviewContents(store)),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _panel(
                    'Burial Trend (12 months)',
                    _BurialTrend(graves: store.graves),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _panel(
                    'Cemetery Map',
                    Column(
                      children: [
                        SizedBox(height: 180, child: _plotOverview(store)),
                        TextButton(
                          onPressed: () => setState(() => selected = 3),
                          child: const Text('Open interactive map'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _panel(
                    'Space Demand',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${store.availableCount} available plots of ${store.graves.length}',
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: store.graves.isEmpty
                              ? 0
                              : store.occupiedCount / store.graves.length,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          forecast == null
                              ? 'A forecast needs at least 12 dated burials across six months in the last two years.'
                              : 'Estimated ${(forecast.yearly.first.occupancy * 100).round()}% occupancy in 12 months.',
                        ),
                        TextButton(
                          onPressed: () => setState(() => selected = 7),
                          child: const Text('View demand analysis'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _panel(
                    'Recent Maintenance Requests',
                    Column(
                      children: [
                        for (final request in store.recentRequests.take(4))
                          ListTile(
                            dense: true,
                            title: Text(request.issue),
                            subtitle: Text(
                              '${store.graveById(request.graveId)?.location ?? request.graveId} · '
                              '${request.priority} priority · ${_dateLabel(request.createdAt)}',
                            ),
                            trailing: Text(request.status),
                          ),
                        if (store.requests.isEmpty)
                          const Text('No requests yet.'),
                        TextButton(
                          onPressed: () => setState(() => selected = 5),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _panel(
                    'Recent Payments',
                    Column(
                      children: [
                        for (final payment in store.recentPayments.take(4))
                          ListTile(
                            dense: true,
                            title: Text(payment.payer),
                            subtitle: Text(
                              '${payment.type} · ${_dateLabel(payment.date)} · ${payment.status}',
                            ),
                            trailing: Text(
                              '₱${payment.amount.toStringAsFixed(2)}',
                            ),
                          ),
                        if (store.payments.isEmpty)
                          const Text('No payments yet.'),
                        TextButton(
                          onPressed: () => setState(() => selected = 4),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _plotOverview(CemeteryStore store) {
    final expiredIds = store.expiredLeaseGraveIdsAt(DateTime.now());
    final rows = store.graves.isEmpty
        ? 4
        : store.graves.map((g) => g.mapRow).reduce(math.max) + 1;
    final columns = store.graves.isEmpty
        ? 5
        : store.graves.map((g) => g.mapColumn).reduce(math.max) + 1;
    return GridView.builder(
      primary: false,
      physics: const ClampingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        mainAxisExtent: 40,
      ),
      itemCount: rows * columns,
      itemBuilder: (context, index) {
        final row = index ~/ columns;
        final column = index % columns;
        Grave? grave;
        for (final item in store.graves) {
          if (item.mapRow == row && item.mapColumn == column) {
            grave = item;
            break;
          }
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: grave?.status == 'occupied' && expiredIds.contains(grave?.id)
                ? Colors.red.shade200
                : grave?.status == 'occupied'
                ? Colors.green.shade700
                : grave?.status == 'reserved'
                ? Colors.amber.shade200
                : grave == null
                ? Colors.grey.shade200
                : Colors.green.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              grave?.lot ?? '',
              style: TextStyle(
                color:
                    grave?.status == 'occupied' &&
                        !expiredIds.contains(grave?.id)
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stat(
    String label,
    int value,
    IconData icon, [
    Color color = const Color(0xFF187246),
    VoidCallback? onTap,
    double width = 205,
  ]) => SizedBox(
    width: width,
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '$value',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'View Details',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0B4A2D)),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _panel(String title, Widget body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          body,
        ],
      ),
    ),
  );

  Widget _countRow(String label, int count, Color color) => ListTile(
    leading: CircleAvatar(backgroundColor: color),
    title: Text(label),
    trailing: Text('$count'),
  );

  Widget _overviewContents(CemeteryStore store) {
    final expired = store.expiredOccupiedCountAt(DateTime.now());
    final activeOccupied = store.occupiedCount - expired;
    final chart = SizedBox(
      width: 145,
      height: 145,
      child: CustomPaint(
        painter: _OccupancyPainter(
          occupied: activeOccupied,
          available: store.availableCount,
          reserved: store.reservedCount,
          expired: expired,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${store.graves.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('Total plots', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
    final legend = Column(
      children: [
        _countRow('Occupied', activeOccupied, Colors.green.shade800),
        _countRow('Available', store.availableCount, Colors.green.shade400),
        _countRow('Reserved', store.reservedCount, Colors.amber),
        _countRow('Expired', expired, Colors.red),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 350
          ? Column(
              children: [
                Center(child: chart),
                legend,
              ],
            )
          : Row(
              children: [
                chart,
                Expanded(child: legend),
              ],
            ),
    );
  }

  String _accountName(CemeteryStore store, String id) {
    for (final account in store.users) {
      if (account['id'] == id) {
        return '${account['name'] ?? account['email'] ?? id}';
      }
    }
    return id;
  }

  String _accountChoiceLabel(Map<String, dynamic> account) {
    final email = '${account['email'] ?? ''}'.trim();
    final name = '${account['name'] ?? ''}'.trim();
    if (email.isNotEmpty) return name.isEmpty ? email : '$email · $name';
    return name.isNotEmpty ? name : '${account['id']}';
  }

  Widget _graveList(CemeteryStore store, {bool occupiedOnly = false}) {
    final query = _graveSearch.text.trim().toLowerCase();
    final graves = store.graves.where((grave) {
      if (occupiedOnly && grave.status != 'occupied') return false;
      if (!occupiedOnly &&
          _graveStatusFilter != 'all' &&
          grave.status != _graveStatusFilter) {
        return false;
      }
      return query.isEmpty ||
          grave.name.toLowerCase().contains(query) ||
          grave.location.toLowerCase().contains(query) ||
          grave.id.toLowerCase().contains(query);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          occupiedOnly ? 'Burial Records' : 'Grave Management',
          occupiedOnly
              ? 'Memorial and burial information'
              : 'Manage plots and availability',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () =>
                _editGrave(null, occupiedOnly ? 'occupied' : 'available'),
            icon: const Icon(Icons.add),
            label: Text(occupiedOnly ? 'Add burial' : 'Add plot'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _graveSearch,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search name or location',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        if (!occupiedOnly) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<String>(
              value: _graveStatusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'available', child: Text('Available')),
                DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
              ],
              onChanged: (value) =>
                  setState(() => _graveStatusFilter = value ?? 'all'),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${graves.length} ${occupiedOnly ? 'burials' : 'plots'} shown',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: graves.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty &&
                            (occupiedOnly || _graveStatusFilter == 'all')
                        ? 'No records yet.'
                        : 'No records match these filters.',
                  ),
                )
              : ListView.builder(
                  itemCount: graves.length,
                  itemBuilder: (context, index) {
                    final grave = graves[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE4F2E8),
                          foregroundColor: const Color(0xFF0B4A2D),
                          child: Text(grave.block),
                        ),
                        title: Text(
                          grave.name.isEmpty ? grave.location : grave.name,
                        ),
                        subtitle: Text('${grave.location} · ${grave.status}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (grave.status == 'occupied')
                              IconButton(
                                tooltip: 'Show grave QR code',
                                icon: const Icon(Icons.qr_code_2),
                                onPressed: () => _showGraveQr(grave),
                              ),
                            IconButton(
                              tooltip: 'Edit grave record',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editGrave(grave),
                            ),
                          ],
                        ),
                        onTap: () => _editGrave(grave),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showGraveQr(Grave grave) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Grave QR code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: grave.qrValue,
              size: 240,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              grave.name,
              style: Theme.of(dialogContext).textTheme.titleMedium,
            ),
            Text(grave.location),
            const SizedBox(height: 8),
            const Text(
              'Place this code on the grave marker. Visitors can scan it in the mobile app.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => _downloadGraveQr(grave),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PNG'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadGraveQr(Grave grave) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(Colors.white, ui.BlendMode.src);
      canvas.translate(72, 72);
      QrPainter(
        data: grave.qrValue,
        version: QrVersions.auto,
      ).paint(canvas, const Size(880, 880));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (data == null) throw StateError('Could not render the QR image.');
      await FileSaver.instance.saveFile(
        name: 'grave-qr-${grave.id}',
        bytes: data.buffer.asUint8List(),
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download QR code: $error')),
        );
      }
    }
  }

  Widget _editableGalleryPhoto(Widget image, VoidCallback remove) => SizedBox(
    width: 76,
    height: 76,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton.filledTonal(
            tooltip: 'Remove memorial photo',
            iconSize: 16,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
            onPressed: remove,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    ),
  );

  Future<void> _editGrave([
    Grave? grave,
    String initialStatus = 'available',
  ]) async {
    final name = TextEditingController(text: grave?.name ?? '');
    final block = TextEditingController(text: grave?.block ?? '');
    final lot = TextEditingController(text: grave?.lot ?? '');
    final number = TextEditingController(text: grave?.number ?? '1');
    final message = TextEditingController(text: grave?.message ?? '');
    final portraitPhoto = TextEditingController(
      text: grave?.portraitPhotoUrl ?? '',
    );
    final tombPhoto = TextEditingController(text: grave?.tombPhotoUrl ?? '');
    final born = TextEditingController(
      text: grave?.born?.toIso8601String().split('T').first ?? '',
    );
    final died = TextEditingController(
      text: grave?.died?.toIso8601String().split('T').first ?? '',
    );
    final buriedAt = TextEditingController(
      text: grave?.buriedAt?.toIso8601String().split('T').first ?? '',
    );
    final birthplace = TextEditingController(text: grave?.birthplace ?? '');
    final deathplace = TextEditingController(text: grave?.deathplace ?? '');
    final latitude = TextEditingController(
      text: grave?.latitude?.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: grave?.longitude?.toString() ?? '',
    );
    var status = grave?.status ?? initialStatus;
    XFile? pendingPhoto;
    Uint8List? photoPreview;
    XFile? pendingPortrait;
    Uint8List? portraitPreview;
    final galleryPhotos = [...?grave?.photos];
    final pendingGalleryPhotos = <XFile>[];
    final galleryPreviews = <Uint8List>[];
    final form = GlobalKey<FormState>();
    final sectionScroll = ScrollController();
    const sectionLabels = ['Plot', 'Burial', 'Photos', 'Map'];
    var activeSection = 0;
    String? plotIdentityError;
    String? dateOrderError;
    final stepTextStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
    final stepSaveStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final editorRoute = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  grave != null
                      ? 'Edit grave record'
                      : initialStatus == 'occupied'
                      ? 'Add burial record'
                      : 'Add grave record',
                ),
              ),
              if (MediaQuery.sizeOf(context).width < 600)
                IconButton(
                  tooltip: 'Cancel edit',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: math.min(
              activeSection == 0
                  ? MediaQuery.sizeOf(context).width < 600
                        ? 390
                        : 320
                  : activeSection == 3
                  ? 280
                  : 500,
              MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var index = 0; index < sectionLabels.length; index++)
                      ChoiceChip(
                        label: Text(sectionLabels[index]),
                        selected: activeSection == index,
                        selectedColor: const Color(0xFFE4F2E8),
                        checkmarkColor: const Color(0xFF0B4A2D),
                        labelStyle: const TextStyle(color: Color(0xFF0B4A2D)),
                        onSelected: (_) {
                          refresh(() => activeSection = index);
                          if (sectionScroll.hasClients) sectionScroll.jumpTo(0);
                        },
                      ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: Form(
                    key: form,
                    child: SingleChildScrollView(
                      controller: sectionScroll,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          Visibility(
                            visible: activeSection == 0,
                            maintainState: true,
                            child: Column(
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Plot identity and availability'),
                                ),
                                const SizedBox(height: 12),
                                _field(block, 'Block', required: true),
                                _field(lot, 'Lot', required: true),
                                _field(number, 'Grave number', required: true),
                                if (plotIdentityError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      plotIdentityError!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: status,
                                    decoration: const InputDecoration(
                                      labelText: 'Status',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['available', 'reserved', 'occupied']
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) =>
                                        refresh(() => status = value ?? status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: activeSection == 1,
                            maintainState: true,
                            child: Column(
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Deceased and memorial details'),
                                ),
                                const SizedBox(height: 12),
                                _field(
                                  name,
                                  'Deceased name',
                                  required: status == 'occupied',
                                ),
                                _dateField(born, 'Birth date (YYYY-MM-DD)'),
                                _dateField(died, 'Death date (YYYY-MM-DD)'),
                                _dateField(
                                  buriedAt,
                                  'Burial date (YYYY-MM-DD)',
                                ),
                                _field(birthplace, 'Birthplace'),
                                _field(deathplace, 'Place of death'),
                                _field(message, 'Family message'),
                                if (dateOrderError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      dateOrderError!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: activeSection == 2,
                            maintainState: true,
                            child: Column(
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Portrait, tomb, and gallery'),
                                ),
                                const SizedBox(height: 12),
                                _field(
                                  portraitPhoto,
                                  'Portrait photo URL (optional)',
                                ),
                                if (portraitPreview != null)
                                  Image.memory(
                                    portraitPreview!,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                if (portraitPreview == null &&
                                    PhotoService.provider(
                                          grave?.portraitPhotoUrl,
                                        ) !=
                                        null)
                                  Image(
                                    image: PhotoService.provider(
                                      grave?.portraitPhotoUrl,
                                    )!,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final photo = await PhotoService.pick(
                                        ImageSource.gallery,
                                      );
                                      if (photo == null) return;
                                      final bytes = await photo.readAsBytes();
                                      refresh(() {
                                        pendingPortrait = photo;
                                        portraitPreview = bytes;
                                      });
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not choose portrait: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.person_outline),
                                  label: const Text('UPLOAD PORTRAIT PHOTO'),
                                ),
                                const SizedBox(height: 12),
                                _field(tombPhoto, 'Tomb photo URL (optional)'),
                                if (photoPreview != null)
                                  Image.memory(
                                    photoPreview!,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                if (photoPreview == null &&
                                    PhotoService.provider(
                                          grave?.tombPhotoUrl,
                                        ) !=
                                        null)
                                  Image(
                                    image: PhotoService.provider(
                                      grave?.tombPhotoUrl,
                                    )!,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final photo = await PhotoService.pick(
                                        ImageSource.gallery,
                                      );
                                      if (photo == null) return;
                                      final bytes = await photo.readAsBytes();
                                      refresh(() {
                                        pendingPhoto = photo;
                                        photoPreview = bytes;
                                      });
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not choose photo: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: const Text('UPLOAD TOMB PHOTO'),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Memorial gallery',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final photo in galleryPhotos)
                                        if (PhotoService.provider(photo) !=
                                            null)
                                          _editableGalleryPhoto(
                                            Image(
                                              image: PhotoService.provider(
                                                photo,
                                              )!,
                                              fit: BoxFit.cover,
                                            ),
                                            () => refresh(
                                              () => galleryPhotos.remove(photo),
                                            ),
                                          ),
                                      for (
                                        var index = 0;
                                        index < galleryPreviews.length;
                                        index++
                                      )
                                        _editableGalleryPhoto(
                                          Image.memory(
                                            galleryPreviews[index],
                                            fit: BoxFit.cover,
                                          ),
                                          () => refresh(() {
                                            pendingGalleryPhotos.removeAt(
                                              index,
                                            );
                                            galleryPreviews.removeAt(index);
                                          }),
                                        ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final photo = await PhotoService.pick(
                                        ImageSource.gallery,
                                      );
                                      if (photo == null) return;
                                      final bytes = await photo.readAsBytes();
                                      refresh(() {
                                        pendingGalleryPhotos.add(photo);
                                        galleryPreviews.add(bytes);
                                      });
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not choose gallery photo: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                  label: const Text('ADD MEMORIAL PHOTO'),
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: activeSection == 3,
                            maintainState: true,
                            child: Column(
                              children: [
                                const Text(
                                  'Place the grave pin on the map. Visitors will use this point for directions.',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  latitude.text.isEmpty ||
                                          longitude.text.isEmpty
                                      ? 'No grave pin selected yet.'
                                      : 'Selected pin: ${latitude.text}, ${longitude.text}',
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final store = CemeteryStore.instance;
                                    final mapCenter = store.mapCenter;
                                    final existingPoint =
                                        grave?.hasValidCoordinates == true
                                        ? geo.LatLng(
                                            grave!.latitude!,
                                            grave.longitude!,
                                          )
                                        : null;
                                    final firstPinned = store.graves
                                        .where(
                                          (record) =>
                                              record.hasValidCoordinates,
                                        )
                                        .firstOrNull;
                                    final center =
                                        existingPoint ??
                                        (mapCenter == null
                                            ? null
                                            : geo.LatLng(
                                                mapCenter.latitude,
                                                mapCenter.longitude,
                                              )) ??
                                        (firstPinned == null
                                            ? null
                                            : geo.LatLng(
                                                firstPinned.latitude!,
                                                firstPinned.longitude!,
                                              ));
                                    if (center == null) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Set the cemetery map center in System Settings first.',
                                              ),
                                            ),
                                          );
                                      return;
                                    }
                                    final chosen = await GravePinPicker.pick(
                                      dialogContext,
                                      title: 'Place grave pin',
                                      center: center,
                                      initialPoint:
                                          latitude.text.isNotEmpty &&
                                              longitude.text.isNotEmpty
                                          ? geo.LatLng(
                                              double.parse(latitude.text),
                                              double.parse(longitude.text),
                                            )
                                          : null,
                                    );
                                    if (chosen == null ||
                                        !dialogContext.mounted) {
                                      return;
                                    }
                                    refresh(() {
                                      latitude.text = chosen.latitude
                                          .toStringAsFixed(6);
                                      longitude.text = chosen.longitude
                                          .toStringAsFixed(6);
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                  ),
                                  label: Text(
                                    latitude.text.isEmpty
                                        ? 'PLACE PIN ON MAP'
                                        : 'MOVE PIN ON MAP',
                                  ),
                                ),
                                if (latitude.text.isNotEmpty &&
                                    longitude.text.isNotEmpty)
                                  TextButton(
                                    onPressed: () => refresh(() {
                                      latitude.clear();
                                      longitude.clear();
                                    }),
                                    child: const Text('Remove pin'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 2,
              runSpacing: 2,
              children: [
                if (MediaQuery.sizeOf(context).width >= 600)
                  TextButton(
                    style: stepTextStyle,
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                if (activeSection > 0)
                  TextButton(
                    style: stepTextStyle,
                    onPressed: () {
                      refresh(() => activeSection--);
                      if (sectionScroll.hasClients) sectionScroll.jumpTo(0);
                    },
                    child: const Text('Back'),
                  ),
                if (activeSection < sectionLabels.length - 1)
                  TextButton(
                    style: stepTextStyle,
                    onPressed: () {
                      refresh(() => activeSection++);
                      if (sectionScroll.hasClients) sectionScroll.jumpTo(0);
                    },
                    child: const Text('Next'),
                  ),
                FilledButton(
                  style: stepSaveStyle,
                  onPressed: () async {
                    if (!form.currentState!.validate()) {
                      final plotInvalid =
                          block.text.trim().isEmpty ||
                          lot.text.trim().isEmpty ||
                          number.text.trim().isEmpty;
                      final burialInvalid =
                          (status == 'occupied' && name.text.trim().isEmpty) ||
                          [born, died, buriedAt].any(
                            (field) =>
                                field.text.trim().isNotEmpty &&
                                parseBurialDate(field.text) == null,
                          );
                      refresh(
                        () => activeSection = plotInvalid
                            ? 0
                            : burialInvalid
                            ? 1
                            : 3,
                      );
                      if (sectionScroll.hasClients) sectionScroll.jumpTo(0);
                      return;
                    }
                    final birthDate = born.text.trim().isEmpty
                        ? null
                        : parseBurialDate(born.text);
                    final deathDate = died.text.trim().isEmpty
                        ? null
                        : parseBurialDate(died.text);
                    final burialDate = buriedAt.text.trim().isEmpty
                        ? null
                        : parseBurialDate(buriedAt.text);
                    final dateError = burialDateOrderError(
                      born: birthDate,
                      died: deathDate,
                      buriedAt: burialDate,
                    );
                    if (dateError != null) {
                      refresh(() {
                        activeSection = 1;
                        dateOrderError = dateError;
                      });
                      if (sectionScroll.hasClients) sectionScroll.jumpTo(0);
                      return;
                    }
                    dateOrderError = null;
                    final duplicate = CemeteryStore.instance.graveAtLocation(
                      block: block.text,
                      lot: lot.text,
                      number: number.text,
                      exceptId: grave?.id,
                    );
                    if (duplicate != null) {
                      refresh(() {
                        activeSection = 0;
                        plotIdentityError = 'A record already exists for this block, lot, and grave number.';
                      });
                      if (sectionScroll.hasClients) sectionScroll.jumpTo(0);
                      return;
                    }
                    plotIdentityError = null;
                    final id =
                        grave?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString();
                    String? uploadedPhoto;
                    String? uploadedPortrait;
                    final savedGalleryPhotos = [...galleryPhotos];
                    try {
                      if (pendingPortrait != null) {
                        uploadedPortrait = await PhotoService.save(
                          pendingPortrait!,
                          path:
                              'grave-photos/$id/portrait-${DateTime.now().microsecondsSinceEpoch}',
                        );
                      }
                      if (pendingPhoto != null) {
                        uploadedPhoto = await PhotoService.save(
                          pendingPhoto!,
                          path:
                              'grave-photos/$id/tomb-${DateTime.now().microsecondsSinceEpoch}',
                        );
                      }
                      for (
                        var index = 0;
                        index < pendingGalleryPhotos.length;
                        index++
                      ) {
                        savedGalleryPhotos.add(
                          await PhotoService.save(
                            pendingGalleryPhotos[index],
                            path:
                                'grave-photos/$id/${DateTime.now().microsecondsSinceEpoch}-$index',
                          ),
                        );
                      }
                    } catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Could not upload photo: $error'),
                          ),
                        );
                      }
                      return;
                    }
                    final record = Grave(
                      id: id,
                      name: name.text.trim(),
                      block: block.text.trim(),
                      lot: lot.text.trim(),
                      number: number.text.trim(),
                      status: status,
                      mapRow:
                          grave?.mapRow ??
                          CemeteryStore.instance.graves.length ~/ 5,
                      mapColumn:
                          grave?.mapColumn ??
                          CemeteryStore.instance.graves.length % 5,
                      born: birthDate,
                      died: deathDate,
                      buriedAt: burialDate,
                      birthplace: birthplace.text.trim(),
                      deathplace: deathplace.text.trim(),
                      message: message.text.trim(),
                      photos: savedGalleryPhotos,
                      portraitPhotoUrl:
                          uploadedPortrait ??
                          (portraitPhoto.text.trim().isEmpty
                              ? null
                              : portraitPhoto.text.trim()),
                      tombPhotoUrl:
                          uploadedPhoto ??
                          (tombPhoto.text.trim().isEmpty
                              ? null
                              : tombPhoto.text.trim()),
                      latitude: double.tryParse(latitude.text.trim()),
                      longitude: double.tryParse(longitude.text.trim()),
                    );
                    try {
                      await CemeteryStore.instance.saveGrave(record);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Could not save record: $error'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context).push(editorRoute);
    // The pop result precedes the reverse animation. Dispose only after
    // Flutter removes the dialog overlay and its fields.
    await editorRoute.completed;
    for (final controller in [
      name,
      block,
      lot,
      number,
      message,
      portraitPhoto,
      tombPhoto,
      born,
      died,
      buriedAt,
      birthplace,
      deathplace,
      latitude,
      longitude,
    ]) {
      controller.dispose();
    }
    sectionScroll.dispose();
  }

  Widget _dateField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        return parseBurialDate(value) == null
            ? 'Enter a real date as YYYY-MM-DD'
            : null;
      },
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    ),
  );

  Widget _maintenance(CemeteryStore store) {
    final visibleRequests = store.recentRequests
        .where(
          (request) =>
              _maintenanceStatusFilter == 'all' ||
              request.status == _maintenanceStatusFilter,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Maintenance', 'Review and update reported issues'),
        DropdownButton<String>(
          value: _maintenanceStatusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All statuses')),
            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
            DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
            DropdownMenuItem(value: 'Completed', child: Text('Completed')),
          ],
          onChanged: (value) =>
              setState(() => _maintenanceStatusFilter = value ?? 'all'),
        ),
        Expanded(
          child: visibleRequests.isEmpty
              ? Center(
                  child: Text(
                    store.requests.isEmpty
                        ? 'No maintenance requests yet.'
                        : 'No requests match this status.',
                  ),
                )
              : ListView(
                  children: [
                    for (final request in visibleRequests)
                      Card(
                        child: ListTile(
                          leading:
                              PhotoService.provider(request.photoUrl) == null
                              ? const Icon(Icons.build_outlined)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image(
                                    image: PhotoService.provider(
                                      request.photoUrl,
                                    )!,
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                          title: Text(request.issue),
                          subtitle: Text(
                            '${store.graveById(request.graveId)?.location ?? request.graveId}\n'
                            '${request.description}\n'
                            '${request.status} · ${request.priority} priority · '
                            '${_dateLabel(request.createdAt)} · '
                            '${_accountName(store, request.requestedBy)}\n'
                            '${request.assignedTo == null ? 'Unassigned' : 'Assigned to ${request.assigneeName ?? _accountName(store, request.assignedTo!)}'}',
                          ),
                          isThreeLine: true,
                          onTap: request.photoUrl == null
                              ? null
                              : () => _showPhoto(request.photoUrl!),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Manage maintenance request',
                            onSelected: (action) => action == 'assign'
                                ? _assignMaintenanceRequest(request)
                                : _updateMaintenanceRequest(request, action),
                            itemBuilder: (_) => [
                              const PopupMenuItem<String>(
                                enabled: false,
                                height: 28,
                                child: Text('Set status'),
                              ),
                              for (final status in [
                                'Pending',
                                'In Progress',
                                'Completed',
                              ])
                                PopupMenuItem<String>(
                                  value: 'status:$status',
                                  height: 40,
                                  child: _checkedMenuLabel(
                                    status,
                                    request.status == status,
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                enabled: false,
                                height: 28,
                                child: Text('Set priority'),
                              ),
                              for (final priority in ['Low', 'Medium', 'High'])
                                PopupMenuItem<String>(
                                  value: 'priority:$priority',
                                  height: 40,
                                  child: _checkedMenuLabel(
                                    priority,
                                    request.priority == priority,
                                  ),
                                ),
                              if (!_isStaff) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem<String>(
                                  value: 'assign',
                                  child: Text('Assign to user'),
                                ),
                              ],
                            ],
                            child: const Icon(Icons.more_vert),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _checkedMenuLabel(String label, bool selected) => Row(
    children: [
      SizedBox(
        width: 24,
        child: selected ? const Icon(Icons.check, size: 18) : null,
      ),
      const SizedBox(width: 8),
      Text(label),
    ],
  );

  Future<void> _updateMaintenanceRequest(
    MaintenanceRequest request,
    String action,
  ) async {
    final separator = action.indexOf(':');
    if (separator < 0) return;
    final field = action.substring(0, separator);
    final value = action.substring(separator + 1);
    try {
      await CemeteryStore.instance.updateRequest(
        request.id,
        field == 'status' ? value : request.status,
        field == 'priority' ? value : request.priority,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update request: $error')),
        );
      }
    }
  }

  Future<void> _assignMaintenanceRequest(MaintenanceRequest request) async {
    final store = CemeteryStore.instance;
    final search = TextEditingController();
    await _showOwnedDialog<void>(
      (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final query = search.text.trim().toLowerCase();
          final accounts = store.users.where((account) {
            if (query.isEmpty) return true;
            return _accountChoiceLabel(account).toLowerCase().contains(query) ||
                '${account['role'] ?? ''}'.toLowerCase().contains(query);
          }).toList();
          Future<void> choose(String? userId) async {
            try {
              await store.assignRequest(request.id, userId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Could not assign request: $error')),
                );
              }
            }
          }

          return AlertDialog(
            title: const Text('Assign maintenance request'),
            content: SizedBox(
              width: 420,
              height: math.min(MediaQuery.sizeOf(context).height * 0.55, 430),
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    onChanged: (_) => refresh(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search registered users',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        if (query.isEmpty)
                          ListTile(
                            leading: const Icon(Icons.person_off_outlined),
                            title: const Text('Unassigned'),
                            trailing: request.assignedTo == null
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => choose(null),
                          ),
                        for (final account in accounts)
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(_accountChoiceLabel(account)),
                            subtitle: Text('${account['role'] ?? 'visitor'}'),
                            trailing: request.assignedTo == account['id']
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => choose('${account['id']}'),
                          ),
                        if (accounts.isEmpty)
                          const ListTile(title: Text('No users match.')),
                      ],
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
    search.dispose();
  }

  void _showPhoto(String source) {
    final image = PhotoService.provider(source);
    if (image == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: Image(
            image: image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Could not load this photo.'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _payments(CemeteryStore store) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Payments & Leases', 'Track payment records and statuses'),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _editPayment(),
            icon: const Icon(Icons.add),
            label: const Text('Add payment'),
          ),
          OutlinedButton.icon(
            onPressed: () => _editLease(),
            icon: const Icon(Icons.add),
            label: const Text('Add lease'),
          ),
        ],
      ),
      Expanded(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 6),
              child: Text(
                'Payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (store.payments.isEmpty)
              const ListTile(title: Text('No payments yet.')),
            for (final payment in store.payments)
              Card(
                child: ListTile(
                  title: Text('${payment.payer} · ${payment.type}'),
                  subtitle: Text(
                    '₱${payment.amount.toStringAsFixed(2)} · ${payment.status}'
                    '${payment.dueDate == null ? '' : ' · Due ${_dateLabel(payment.dueDate!)}'}'
                    '${store.graveById(payment.graveId) == null ? '' : '\n${store.graveById(payment.graveId)!.location}'}'
                    '${payment.attachments.isEmpty ? '' : '\n${payment.attachments.length} supporting file${payment.attachments.length == 1 ? '' : 's'}'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Manage payment',
                    onSelected: (action) {
                      if (action == 'Edit') {
                        _editPayment(payment);
                      } else if (action == 'Documents') {
                        _showPaymentDocuments(payment);
                      } else {
                        _changePaymentStatus(payment, action);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'Edit', child: Text('Edit')),
                      if (payment.attachments.isNotEmpty)
                        const PopupMenuItem(
                          value: 'Documents',
                          child: Text('Supporting documents'),
                        ),
                      ...['Pending', 'Paid', 'Overdue'].map(
                        (status) => PopupMenuItem(
                          value: status,
                          child: Text('Mark $status'),
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 22, bottom: 6),
              child: Text(
                'Leases',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (store.leases.isEmpty)
              const ListTile(title: Text('No leases yet.')),
            for (final lease in store.leases)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    '${lease.lessee} · ${store.graveById(lease.graveId)?.location ?? lease.graveId}',
                  ),
                  subtitle: Text(
                    '${_dateLabel(lease.startsAt)} to ${_dateLabel(lease.endsAt)} · ${lease.effectiveStatus(DateTime.now())}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit lease',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editLease(lease),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Future<T?> _showOwnedDialog<T>(WidgetBuilder builder) async {
    final route = DialogRoute<T>(context: context, builder: builder);
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    return result;
  }

  Future<void> _editPayment([PaymentRecord? existing]) async {
    final store = CemeteryStore.instance;
    final payer = TextEditingController(text: existing?.payer ?? '');
    final type = TextEditingController(text: existing?.type ?? 'Annual Fee');
    final amount = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    final dueDate = TextEditingController(
      text: _dateLabel(
        existing?.dueDate ?? DateTime.now().add(const Duration(days: 30)),
      ),
    );
    String? ownerId = existing?.ownerId;
    String? graveId = existing?.graveId;
    final attachments = [...?existing?.attachments];
    final pendingFiles = <XFile>[];
    final form = GlobalKey<FormState>();
    await _showOwnedDialog<void>(
      (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(existing == null ? 'Add payment' : 'Edit payment'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(payer, 'Payer', required: true),
                    _field(type, 'Type', required: true),
                    TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₱)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        return parsed == null || !parsed.isFinite || parsed <= 0
                            ? 'Enter a positive amount'
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: graveId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Grave / plot',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final grave in store.graves)
                          DropdownMenuItem(
                            value: grave.id,
                            child: Text(
                              grave.name.isEmpty
                                  ? grave.location
                                  : '${grave.name} · ${grave.location}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (graveId != null &&
                            store.graveById(graveId!) == null)
                          DropdownMenuItem(
                            value: graveId,
                            child: Text('Missing plot · $graveId'),
                          ),
                      ],
                      onChanged: (value) => graveId = value,
                      validator: (value) =>
                          value == null ? 'Select a grave or plot' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: ownerId ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Visitor account for reminders',
                        helperText: 'Only linked accounts see this due date.',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No account linked'),
                        ),
                        for (final user in store.users.where(
                          (user) => user['role'] == 'visitor',
                        ))
                          DropdownMenuItem(
                            value: '${user['id']}',
                            child: Text(
                              _accountChoiceLabel(user),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (ownerId != null &&
                            !store.users.any(
                              (user) =>
                                  user['id'] == ownerId &&
                                  user['role'] == 'visitor',
                            ))
                          DropdownMenuItem(
                            value: ownerId,
                            child: Text('Linked account $ownerId'),
                          ),
                      ],
                      onChanged: (value) => ownerId =
                          value == null || value.isEmpty ? null : value,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dueDate,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Due date',
                        suffixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate:
                              DateTime.tryParse(dueDate.text) ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          dueDate.text = _dateLabel(selected);
                        }
                      },
                      validator: (value) =>
                          DateTime.tryParse(value ?? '') == null
                          ? 'Choose a due date'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Supporting documents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Receipts, screenshots, PDF, or Word files.'),
                    ),
                    for (final attachment in attachments)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.attach_file),
                        title: Text(
                          attachment.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _downloadPaymentDocument(attachment),
                        trailing: IconButton(
                          tooltip: 'Remove ${attachment.name}',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              refresh(() => attachments.remove(attachment)),
                        ),
                      ),
                    for (final file in pendingFiles)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.upload_file_outlined),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: 'Remove ${file.name}',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              refresh(() => pendingFiles.remove(file)),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final selected = await PaymentDocumentService.pick();
                          if (selected.isNotEmpty) {
                            refresh(() => pendingFiles.addAll(selected));
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Could not choose files: $error'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('ADD SUPPORTING FILES'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final id =
                    existing?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString();
                final uploaded = <PaymentAttachment>[];
                try {
                  for (final file in pendingFiles) {
                    uploaded.add(
                      await PaymentDocumentService.save(file, paymentId: id),
                    );
                  }
                  await CemeteryStore.instance.savePayment(
                    PaymentRecord(
                      id: id,
                      payer: payer.text.trim(),
                      graveId: graveId!,
                      type: type.text.trim(),
                      amount: double.parse(amount.text),
                      date: existing?.date ?? DateTime.now(),
                      dueDate: DateTime.parse(dueDate.text),
                      ownerId: ownerId,
                      status: existing?.status ?? 'Pending',
                      attachments: [...attachments, ...uploaded],
                    ),
                  );
                  for (final removed
                      in existing?.attachments ?? const <PaymentAttachment>[]) {
                    if (!attachments.contains(removed)) {
                      try {
                        await PaymentDocumentService.delete(removed);
                      } catch (_) {
                        // The saved payment no longer references this file.
                      }
                    }
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (error) {
                  for (final attachment in uploaded) {
                    try {
                      await PaymentDocumentService.delete(attachment);
                    } catch (_) {
                      // A later storage cleanup can remove this unused file.
                    }
                  }
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Could not save payment: $error')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    payer.dispose();
    type.dispose();
    amount.dispose();
    dueDate.dispose();
  }

  Future<void> _changePaymentStatus(
    PaymentRecord payment,
    String status,
  ) async {
    try {
      await CemeteryStore.instance.savePayment(
        payment.copyWith(status: status),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update payment: $error')),
        );
      }
    }
  }

  Future<void> _showPaymentDocuments(PaymentRecord payment) =>
      _showOwnedDialog<void>(
        (dialogContext) => AlertDialog(
          title: const Text('Supporting documents'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final attachment in payment.attachments)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(attachment.name),
                    trailing: const Icon(Icons.download_outlined),
                    onTap: () => _downloadPaymentDocument(attachment),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  Future<void> _downloadPaymentDocument(PaymentAttachment attachment) async {
    try {
      await PaymentDocumentService.download(attachment);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download file: $error')),
        );
      }
    }
  }

  Future<void> _editLease([LeaseRecord? existing]) async {
    final store = CemeteryStore.instance;
    final lessee = TextEditingController(text: existing?.lessee ?? '');
    final startDate = TextEditingController(
      text: _dateLabel(existing?.startsAt ?? DateTime.now()),
    );
    final endDate = TextEditingController(
      text: _dateLabel(
        existing?.endsAt ?? DateTime.now().add(const Duration(days: 365)),
      ),
    );
    String? graveId = existing?.graveId;
    String? ownerId = existing?.ownerId;
    String status = existing?.status ?? 'Active';
    final form = GlobalKey<FormState>();

    Future<void> pickDate(
      BuildContext dialogContext,
      TextEditingController controller,
    ) async {
      final selected = await showDatePicker(
        context: dialogContext,
        initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (selected != null) controller.text = _dateLabel(selected);
    }

    await _showOwnedDialog<void>(
      (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add lease' : 'Edit lease'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(lessee, 'Lessee', required: true),
                  DropdownButtonFormField<String>(
                    initialValue: graveId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Grave / plot',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        store.graves
                            .map(
                              (grave) => DropdownMenuItem(
                                value: grave.id,
                                child: Text(
                                  grave.name.isEmpty
                                      ? grave.location
                                      : '${grave.name} · ${grave.location}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList()
                          ..insertAll(0, [
                            if (graveId != null &&
                                store.graveById(graveId!) == null)
                              DropdownMenuItem(
                                value: graveId,
                                child: Text('Missing plot · $graveId'),
                              ),
                          ]),
                    onChanged: (value) => graveId = value,
                    validator: (value) =>
                        value == null ? 'Select a grave or plot' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ownerId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Visitor account (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        store.users
                            .where((user) => user['role'] == 'visitor')
                            .map(
                              (user) => DropdownMenuItem(
                                value: '${user['id']}',
                                child: Text(
                                  _accountChoiceLabel(user),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList()
                          ..insertAll(0, [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('No linked account'),
                            ),
                            if (ownerId != null &&
                                !store.users.any(
                                  (user) =>
                                      user['id'] == ownerId &&
                                      user['role'] == 'visitor',
                                ))
                              DropdownMenuItem(
                                value: ownerId,
                                child: Text('Account $ownerId'),
                              ),
                          ]),
                    onChanged: (value) => ownerId = value == '' ? null : value,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: startDate,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Start date',
                      suffixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => pickDate(dialogContext, startDate),
                    validator: (value) => DateTime.tryParse(value ?? '') == null
                        ? 'Choose a start date'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: endDate,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'End date',
                      suffixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => pickDate(dialogContext, endDate),
                    validator: (value) {
                      final start = DateTime.tryParse(startDate.text);
                      final end = DateTime.tryParse(value ?? '');
                      if (end == null) return 'Choose an end date';
                      if (start != null && end.isBefore(start)) {
                        return 'End date must follow start date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Active', 'Expired', 'Terminated']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => status = value ?? status,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await store.saveLease(
                  LeaseRecord(
                    id:
                        existing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    graveId: graveId!,
                    lessee: lessee.text.trim(),
                    ownerId: ownerId,
                    startsAt: DateTime.parse(startDate.text),
                    endsAt: DateTime.parse(endDate.text),
                    status: status,
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not save lease: $error')),
                  );
                }
              }
            },
            child: const Text('Save lease'),
          ),
        ],
      ),
    );
    lessee.dispose();
    startDate.dispose();
    endDate.dispose();
  }

  String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _reports(CemeteryStore store) => LayoutBuilder(
    builder: (context, constraints) {
      final contentWidth = constraints.maxWidth;
      final columns = contentWidth >= 900
          ? 4
          : contentWidth >= 520
          ? 2
          : 1;
      final cardWidth = (contentWidth - (columns - 1) * 12) / columns;
      return ListView(
        children: [
          _heading(
            'Reports & Analytics',
            'Current records and operational totals',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final report in OperationsReport.values)
                OutlinedButton.icon(
                  onPressed: () => _downloadReport(report),
                  icon: const Icon(Icons.download_outlined),
                  label: Text('Download ${reportLabel(report)} CSV'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat(
                'Burials',
                store.occupiedCount,
                Icons.person,
                const Color(0xFF187246),
                null,
                cardWidth,
              ),
              _stat(
                'Available',
                store.availableCount,
                Icons.grid_on,
                const Color(0xFF187246),
                null,
                cardWidth,
              ),
              _stat(
                'Reserved',
                store.reservedCount,
                Icons.bookmark,
                const Color(0xFF187246),
                null,
                cardWidth,
              ),
              _stat(
                'Payments',
                store.payments.length,
                Icons.payments,
                const Color(0xFF187246),
                null,
                cardWidth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _panel(
            'Maintenance status',
            Column(
              children: [
                for (final (status, color) in [
                  ('Pending', Colors.amber),
                  ('In Progress', Colors.blue),
                  ('Completed', Colors.green),
                ])
                  _countRow(
                    status,
                    store.requests.where((r) => r.status == status).length,
                    color,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            'Visitor feedback',
            Column(
              children: [
                if (store.feedback.isEmpty)
                  const ListTile(title: Text('No feedback submitted yet.')),
                for (final item
                    in (store.feedback.toList()..sort(
                          (a, b) => '${b['createdAt']}'.compareTo(
                            '${a['createdAt']}',
                          ),
                        ))
                        .take(10))
                  ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: Text(
                      '${item['rating']}/5 · '
                      '${_accountName(store, '${item['userId']}')}',
                    ),
                    subtitle: Text('${item['message'] ?? ''}'),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Future<void> _downloadReport(OperationsReport report) async {
    try {
      final csv = buildReportCsv(report, CemeteryStore.instance);
      await FileSaver.instance.saveFile(
        name: '${reportFileName(report)}-${_dateLabel(DateTime.now())}',
        bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download report: $error')),
        );
      }
    }
  }

  Widget _predictions(CemeteryStore store) {
    final total = store.graves.length;
    final occupied = store.occupiedCount;
    final forecast = forecastDemand(store.graves);
    return ListView(
      children: [
        _heading('ML Predictions', 'Space demand and occupancy planning'),
        _panel(
          'Occupancy',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$occupied of $total plots occupied'),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: total == 0 ? 0 : occupied / total),
              const SizedBox(height: 12),
              Text(
                forecast == null
                    ? 'A forecast needs at least 12 dated burials across six months in the last two years.'
                    : '${forecast.observedBurials} dated burials used · '
                          '${forecast.monthlyBurials.toStringAsFixed(1)} expected burials per month initially.',
              ),
            ],
          ),
        ),
        if (forecast != null) ...[
          const SizedBox(height: 16),
          _panel(
            'Predicted occupancy (next 5 years)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 190,
                  child: CustomPaint(
                    painter: _ForecastPainter([
                      occupied / total,
                      ...forecast.yearly.map((estimate) => estimate.occupancy),
                    ]),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
                for (final estimate in forecast.yearly)
                  ListTile(
                    dense: true,
                    title: Text('${estimate.date.month}/${estimate.date.year}'),
                    subtitle: Text(
                      '${estimate.projectedOccupied} of $total plots',
                    ),
                    trailing: Text('${(estimate.occupancy * 100).round()}%'),
                  ),
                if (forecast.nearCapacity != null)
                  ListTile(
                    leading: const Icon(
                      Icons.warning_amber,
                      color: Colors.deepOrange,
                    ),
                    title: Text(
                      'At least 90% occupied by '
                      '${forecast.nearCapacity!.date.month}/${forecast.nearCapacity!.date.year}',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            'How this estimate works',
            const Text(
              'A linear trend is fitted to monthly burial counts from the last 24 months. '
              'Future monthly demand is capped at twice the observed average. '
              'This is a planning estimate, not a guarantee; it assumes no new plots are added.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _staff(CemeteryStore store) {
    final selfId = store.isDemo
        ? 'preview-admin'
        : FirebaseAuth.instance.currentUser?.uid;
    final accountQuery = _accountSearch.text.trim().toLowerCase();
    final visibleAccounts = store.users.where((account) {
      if (accountQuery.isEmpty) return true;
      return [
        account['name'],
        account['email'],
        account['role'],
      ].any((value) => '${value ?? ''}'.toLowerCase().contains(accountQuery));
    }).toList();
    return ListView(
      children: [
        _heading(
          'User Management',
          'Accounts, access roles, and staff directory',
        ),
        _panel(
          store.isDemo ? 'Preview accounts' : 'Registered accounts',
          Column(
            children: [
              if (!store.isDemo)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _createStaffLogin,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Create staff login'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _accountSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search accounts',
                    hintText: 'Name, email, or role',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (store.users.isEmpty)
                const ListTile(
                  title: Text('No accounts found'),
                  subtitle: Text(
                    'Accounts appear here after a visitor signs up.',
                  ),
                ),
              if (store.users.isNotEmpty && visibleAccounts.isEmpty)
                const ListTile(title: Text('No accounts match this search.')),
              for (final account in visibleAccounts)
                Builder(
                  builder: (context) {
                    final narrow = MediaQuery.sizeOf(context).width < 800;
                    final roleControl = account['id'] == selfId
                        ? const Chip(label: Text('Current admin'))
                        : PopupMenuButton<String>(
                            tooltip: 'Change account role',
                            onSelected: (role) =>
                                _changeUserRole('${account['id']}', role),
                            itemBuilder: (_) => ['visitor', 'staff', 'admin']
                                .map(
                                  (role) => PopupMenuItem(
                                    value: role,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: account['role'] == role
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 18,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          role == 'admin'
                                              ? 'Administrator'
                                              : role == 'staff'
                                              ? 'Staff'
                                              : 'Visitor',
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF0B4A2D),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Role: ${account['role'] == 'admin'
                                        ? 'Administrator'
                                        : account['role'] == 'staff'
                                        ? 'Staff'
                                        : 'Visitor'}',
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                            ),
                          );
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE4F2E8),
                        foregroundColor: Color(0xFF0B4A2D),
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        '${account['name'] ?? account['email'] ?? account['id']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: narrow
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${account['email'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                roleControl,
                              ],
                            )
                          : Text(
                              '${account['email'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: narrow ? null : roleControl,
                      isThreeLine: narrow,
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          'Staff directory',
          Column(
            children: [
              const ListTile(
                dense: true,
                title: Text(
                  'Directory entries do not create login accounts. Change access roles in the account list above.',
                ),
              ),
              if (store.staff.isEmpty)
                const ListTile(title: Text('No staff records yet.')),
              for (final person in store.staff)
                ListTile(
                  title: Text('${person['name'] ?? ''}'),
                  subtitle: Text(
                    '${person['role'] ?? ''} · ${person['email'] ?? ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Manage staff entry',
                    onSelected: (action) => action == 'edit'
                        ? _editStaff(person)
                        : _deleteStaff(person),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _editStaff(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add staff contact'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changeUserRole(String userId, String role) async {
    final store = CemeteryStore.instance;
    final account = store.users
        .where((user) => user['id'] == userId)
        .firstOrNull;
    if (account == null || account['role'] == role) return;
    final name = '${account['name'] ?? account['email'] ?? userId}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          role == 'admin'
              ? 'Grant administrator access?'
              : role == 'staff'
              ? 'Grant staff access?'
              : 'Change account to visitor?',
        ),
        content: Text(
          role == 'admin'
              ? '$name will be able to manage cemetery records and other account roles.'
              : role == 'staff'
              ? '$name will be able to manage burial records, graves, map pins, and maintenance requests.'
              : '$name will lose access to the web administration dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await store.updateUserRole(userId, role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account role changed to $role.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change role: $error')),
        );
      }
    }
  }

  Future<void> _createStaffLogin() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final form = GlobalKey<FormState>();
    var creating = false;
    await _showOwnedDialog<void>(
      (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Create staff login'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Name', required: true),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final address = value?.trim() ?? '';
                      return address.contains('@') && address.contains('.')
                          ? null
                          : 'Enter a valid email address';
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A unique temporary password will be shown once after the account is created.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: creating
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      refresh(() => creating = true);
                      final password = StaffAccountService.temporaryPassword();
                      final newEmail = email.text.trim();
                      try {
                        await StaffAccountService.create(
                          name: name.text.trim(),
                          email: newEmail,
                          password: password,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          await showDialog<void>(
                            context: this.context,
                            builder: (successContext) => AlertDialog(
                              title: const Text('Staff login created'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(newEmail),
                                  const SizedBox(height: 12),
                                  const Text('Temporary password'),
                                  SelectableText(password),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Share this password with the staff member. It will not be shown again.',
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton.icon(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(text: password),
                                  ),
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy password'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(successContext),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not create staff login: $error',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          refresh(() => creating = false);
                        }
                      }
                    },
              child: Text(creating ? 'Creating…' : 'Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    email.dispose();
  }

  Future<void> _editStaff([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final email = TextEditingController(text: '${existing?['email'] ?? ''}');
    final role = TextEditingController(text: '${existing?['role'] ?? 'Staff'}');
    final form = GlobalKey<FormState>();
    await _showOwnedDialog<void>(
      (dialogContext) => AlertDialog(
        title: Text(
          existing == null ? 'Add staff contact' : 'Edit staff contact',
        ),
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Name', required: true),
                _field(email, 'Email', required: true),
                _field(role, 'Role', required: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await CemeteryStore.instance.saveStaff({
                  'id':
                      existing?['id'] ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'role': role.text.trim(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not save staff: $error')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    role.dispose();
  }

  Future<void> _deleteStaff(Map<String, dynamic> person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove staff entry?'),
        content: Text(
          'Remove ${person['name'] ?? 'this person'} from the staff directory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CemeteryStore.instance.deleteStaff('${person['id']}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove staff entry: $error')),
        );
      }
    }
  }

  Widget _settings(CemeteryStore store) => ListView(
    children: [
      _heading('System Settings', 'Visitor information and announcements'),
      _panel(
        'Data source',
        Text(
          store.isDemo
              ? 'Local preview data is stored in this browser only. Configure Firebase to share records across devices.'
              : 'Connected to Cloud Firestore. Access control must be enforced through Firestore security rules.',
        ),
      ),
      const SizedBox(height: 12),
      _panel(
        store.isDemo ? 'Encrypted local backup' : 'Cloud backups',
        store.isDemo
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save an encrypted copy of the records in this browser. Keep the passphrase safe; it is required to restore the file.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _backupBusy ? null : _downloadBackup,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download backup'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _backupBusy ? null : _restoreBackup,
                        icon: const Icon(Icons.restore_outlined),
                        label: const Text('Restore backup'),
                      ),
                    ],
                  ),
                  if (_backupBusy) const LinearProgressIndicator(),
                ],
              )
            : const Text(
                'A project owner must configure scheduled Firestore backups, protect Storage photos, and separately export Authentication accounts. Check backup status and recovery in Google Cloud; this browser cannot create a complete cloud backup.',
              ),
      ),
      const SizedBox(height: 12),
      _panel(
        'Visitor information',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Visiting hours'),
              subtitle: Text('${store.settings['visitingHours'] ?? 'Not set'}'),
            ),
            ListTile(
              title: const Text('Guidelines'),
              subtitle: Text('${store.settings['guidelines'] ?? 'Not set'}'),
            ),
            ListTile(
              title: const Text('Emergency contact'),
              subtitle: Text(
                '${store.settings['emergencyContact'] ?? 'Not set'}',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _editSettings,
                icon: const Icon(Icons.edit),
                label: const Text('Edit information'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _panel(
        'Cemetery map center',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.mapCenter == null
                  ? 'Set the cemetery center to place the first grave pin in Map Management.'
                  : 'Latitude ${store.mapCenter!.latitude.toStringAsFixed(6)}, longitude ${store.mapCenter!.longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a verified point inside the cemetery. Visitors receive directions to each grave pin, not this center.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _editMapCenter,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Set map center'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _panel(
        'Grave map markers',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how occupied, reserved, and available graves appear on the map.',
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'tombstone',
                  label: Text('Tombstone'),
                  icon: Icon(Icons.church_outlined),
                ),
                ButtonSegment(
                  value: 'pin',
                  label: Text('Map pin'),
                  icon: Icon(Icons.location_pin),
                ),
              ],
              selected: {'${store.settings['gravePinStyle'] ?? 'tombstone'}'},
              onSelectionChanged: (values) async {
                try {
                  await store.saveSettings({'gravePinStyle': values.first});
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not change grave markers: $error'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _panel(
        'Announcements',
        Column(
          children: [
            if (store.announcements.isEmpty)
              const ListTile(title: Text('No announcements published.')),
            for (final item in store.recentAnnouncements)
              ListTile(
                title: Text('${item['title'] ?? ''}'),
                subtitle: Text('${item['body'] ?? ''}'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Manage announcement',
                  onSelected: (action) => action == 'edit'
                      ? _editAnnouncement(item)
                      : _deleteAnnouncement(item),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Withdraw')),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editAnnouncement(),
                icon: const Icon(Icons.add),
                label: const Text('Add announcement'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Future<String?> _askBackupPassphrase({required bool creating}) async {
    final passphrase = TextEditingController();
    final confirmation = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await _showOwnedDialog<String>(
      (dialogContext) => AlertDialog(
        title: Text(creating ? 'Protect backup' : 'Unlock backup'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passphrase,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Passphrase'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a passphrase';
                    }
                    if (creating && value.trim().length < 12) {
                      return 'Use at least 12 characters';
                    }
                    return null;
                  },
                ),
                if (creating)
                  TextFormField(
                    controller: confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm passphrase',
                    ),
                    validator: (value) => value != passphrase.text
                        ? 'Passphrases do not match'
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, passphrase.text);
              }
            },
            child: Text(creating ? 'Create backup' : 'Unlock'),
          ),
        ],
      ),
    );
    passphrase.dispose();
    confirmation.dispose();
    return result;
  }

  Future<void> _downloadBackup() async {
    final passphrase = await _askBackupPassphrase(creating: true);
    if (passphrase == null || !mounted) return;
    setState(() => _backupBusy = true);
    try {
      final snapshot = CemeteryStore.instance.exportPreviewSnapshot();
      final bytes = await BackupService.encrypt(snapshot, passphrase);
      final now = DateTime.now();
      await FileSaver.instance.saveFile(
        name:
            'smart-cemetery-backup-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encrypted backup downloaded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create backup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    try {
      const type = XTypeGroup(
        label: 'Smart Cemetery backup',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      final file = await openFile(acceptedTypeGroups: [type]);
      if (file == null || !mounted) return;
      if (await file.length() > BackupService.maxFileBytes) {
        throw const FormatException('Backup file is too large.');
      }
      final passphrase = await _askBackupPassphrase(creating: false);
      if (passphrase == null || !mounted) return;
      setState(() => _backupBusy = true);
      final snapshot = await BackupService.decrypt(
        await file.readAsBytes(),
        passphrase,
      );
      final store = CemeteryStore.instance;
      final counts = store.previewSnapshotCounts(snapshot);
      if (!mounted) return;
      setState(() => _backupBusy = false);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore local preview?'),
          content: Text(
            'This replaces the records in this browser with the backup: '
            '${counts['graves']} graves, ${counts['requests']} requests, '
            '${counts['payments']} payments, and ${counts['visits']} visits.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _backupBusy = true);
      await store.restorePreviewSnapshot(snapshot);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local preview restored.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore backup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _editSettings() async {
    final store = CemeteryStore.instance;
    final hours = TextEditingController(
      text: '${store.settings['visitingHours'] ?? ''}',
    );
    final guidelines = TextEditingController(
      text: '${store.settings['guidelines'] ?? ''}',
    );
    final contact = TextEditingController(
      text: '${store.settings['emergencyContact'] ?? ''}',
    );
    await _showOwnedDialog<void>(
      (dialogContext) => AlertDialog(
        title: const Text('Visitor information'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(hours, 'Visiting hours'),
                _field(guidelines, 'Guidelines'),
                _field(contact, 'Emergency contact'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await store.saveSettings({
                  'visitingHours': hours.text.trim(),
                  'guidelines': guidelines.text.trim(),
                  'emergencyContact': contact.text.trim(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not save settings: $error')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    hours.dispose();
    guidelines.dispose();
    contact.dispose();
  }

  Future<void> _editMapCenter() async {
    final store = CemeteryStore.instance;
    final configured = store.mapCenter;
    final firstPinned = store.graves
        .where((grave) => grave.hasValidCoordinates)
        .firstOrNull;
    final current = configured == null
        ? null
        : geo.LatLng(configured.latitude, configured.longitude);
    final center =
        current ??
        (firstPinned == null
            ? const geo.LatLng(14.5995, 120.9842)
            : geo.LatLng(firstPinned.latitude!, firstPinned.longitude!));
    final chosen = await GravePinPicker.pick(
      context,
      title: 'Set cemetery map center',
      center: center,
      initialPoint: current,
      initialZoom: current == null && firstPinned == null ? 12 : 18,
    );
    if (chosen == null || !mounted) return;
    try {
      await store.saveSettings({
        'mapCenterLatitude': chosen.latitude,
        'mapCenterLongitude': chosen.longitude,
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save map center: $error')),
        );
      }
    }
  }

  Future<void> _editAnnouncement([Map<String, dynamic>? existing]) async {
    final title = TextEditingController(text: '${existing?['title'] ?? ''}');
    final body = TextEditingController(text: '${existing?['body'] ?? ''}');
    final form = GlobalKey<FormState>();
    await _showOwnedDialog<void>(
      (dialogContext) => AlertDialog(
        title: Text(
          existing == null ? 'Add announcement' : 'Edit announcement',
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(title, 'Title', required: true),
                _field(body, 'Message', required: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await CemeteryStore.instance.saveAnnouncement({
                  'id':
                      existing?['id'] ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  'title': title.text.trim(),
                  'body': body.text.trim(),
                  'date': existing?['date'] ?? DateTime.now().toIso8601String(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Could not save announcement: $error'),
                    ),
                  );
                }
              }
            },
            child: Text(existing == null ? 'Publish' : 'Save'),
          ),
        ],
      ),
    );
    title.dispose();
    body.dispose();
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw announcement?'),
        content: Text(
          'Remove "${item['title'] ?? 'this announcement'}" from visitor announcements?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CemeteryStore.instance.deleteAnnouncement('${item['id']}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not withdraw announcement: $error')),
        );
      }
    }
  }
}

class _OccupancyPainter extends CustomPainter {
  final int occupied;
  final int available;
  final int reserved;
  final int expired;
  _OccupancyPainter({
    required this.occupied,
    required this.available,
    required this.reserved,
    required this.expired,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final total = occupied + available + reserved + expired;
    final base = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawArc(rect.deflate(14), 0, math.pi * 2, false, base);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final (count, color) in [
      (occupied, Colors.green.shade800),
      (available, Colors.green.shade400),
      (reserved, Colors.amber),
      (expired, Colors.red),
    ]) {
      final sweep = math.pi * 2 * count / total;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect.deflate(14),
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_OccupancyPainter oldDelegate) =>
      oldDelegate.occupied != occupied ||
      oldDelegate.available != available ||
      oldDelegate.reserved != reserved ||
      oldDelegate.expired != expired;
}

class _BurialTrend extends StatelessWidget {
  final List<Grave> graves;
  const _BurialTrend({required this.graves});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(
      12,
      (index) => DateTime(now.year, now.month - 11 + index),
    );
    final counts = [
      for (final month in months)
        graves
            .where(
              (grave) =>
                  grave.buriedAt != null &&
                  grave.buriedAt!.year == month.year &&
                  grave.buriedAt!.month == month.month,
            )
            .length,
    ];
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: CustomPaint(
            painter: _TrendPainter(counts),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${months.first.month}/${months.first.year}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              '${months.last.month}/${months.last.year}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        if (counts.every((count) => count == 0))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No burial dates in this period.'),
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<int> counts;
  _TrendPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = 12 + (size.height - 24) * index / 3;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    final maximum = math.max(1, counts.reduce(math.max));
    final points = [
      for (var index = 0; index < counts.length; index++)
        Offset(
          8 + (size.width - 16) * index / 11,
          size.height - 12 - (size.height - 24) * counts[index] / maximum,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1B4D2E)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = const Color(0xFF1B4D2E));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.counts.toString() != counts.toString();
}

class _ForecastPainter extends CustomPainter {
  final List<double> occupancy;
  _ForecastPainter(this.occupancy);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 12.0;
    final right = size.width - 12;
    const top = 12.0;
    final bottom = size.height - 12;
    for (final fraction in [0.0, 0.5, 0.9, 1.0]) {
      final y = bottom - (bottom - top) * fraction;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = fraction == 0.9
              ? Colors.orange.shade300
              : Colors.grey.shade300
          ..strokeWidth = 1,
      );
    }
    final points = [
      for (var index = 0; index < occupancy.length; index++)
        Offset(
          left + (right - left) * index / (occupancy.length - 1),
          bottom - (bottom - top) * occupancy[index],
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF087B94)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = const Color(0xFF087B94));
    }
  }

  @override
  bool shouldRepaint(_ForecastPainter oldDelegate) =>
      oldDelegate.occupancy.toString() != occupancy.toString();
}
