import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';

import '../services/firebase_setup.dart';
import '../services/photo_service.dart';

import '../data/cemetery_store.dart';
import '../models/cemetery_models.dart';

class RequestMaintenanceScreen extends StatefulWidget {
  final String? graveId;
  const RequestMaintenanceScreen({super.key, this.graveId});

  @override
  State<RequestMaintenanceScreen> createState() =>
      _RequestMaintenanceScreenState();
}

class _RequestMaintenanceScreenState extends State<RequestMaintenanceScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _graveId;
  String _issue = 'Damaged Tombstone';
  bool _submitting = false;
  XFile? _photo;
  Uint8List? _photoPreview;

  @override
  void initState() {
    super.initState();
    _graveId = widget.graveId;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _graveId == null) return;
    setState(() => _submitting = true);
    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final ownerId = FirebaseSetup.configured
          ? FirebaseAuth.instance.currentUser?.uid
          : 'preview-visitor';
      if (ownerId == null || ownerId.isEmpty) {
        throw StateError('Sign in to submit a maintenance request.');
      }
      final photoUrl = _photo == null
          ? null
          : await PhotoService.save(_photo!, path: 'maintenance/$ownerId/$id');
      await CemeteryStore.instance.addRequest(
        MaintenanceRequest(
          id: id,
          graveId: _graveId!,
          issue: _issue,
          description: _description.text.trim(),
          requestedBy: ownerId,
          createdAt: DateTime.now(),
          photoUrl: photoUrl,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance request submitted.')),
      );
      _description.clear();
      setState(() {
        _photo = null;
        _photoPreview = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit request: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final photo = await PhotoService.pick(source);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (mounted) {
        setState(() {
          _photo = photo;
          _photoPreview = bytes;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not choose photo: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CemeteryStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Request Maintenance')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final visitorId = FirebaseSetup.configured
              ? FirebaseAuth.instance.currentUser?.uid
              : 'preview-visitor';
          final myRequests =
              store.requests
                  .where((request) => request.requestedBy == visitorId)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final graves = store.graves
              .where((g) => g.status == 'occupied')
              .toList();
          final selected = graves.any((g) => g.id == _graveId)
              ? _graveId
              : null;
          return Form(
            key: _form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              children: [
                if (graves.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No occupied graves are available for requests.',
                    ),
                  )
                else
                  FormField<String>(
                    initialValue: selected,
                    validator: (value) =>
                        value == null ||
                            !graves.any((grave) => grave.id == value)
                        ? 'Select a grave'
                        : null,
                    builder: (field) {
                      final chosen = graves
                          .where((grave) => grave.id == field.value)
                          .firstOrNull;
                      return Semantics(
                        button: true,
                        label: 'Choose grave or location',
                        child: InkWell(
                          onTap: () async {
                            final grave = await showSearch<Grave?>(
                              context: context,
                              delegate: _GraveSearchDelegate(graves),
                            );
                            if (grave == null || !mounted || !field.mounted) {
                              return;
                            }
                            field.didChange(grave.id);
                            setState(() => _graveId = grave.id);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Grave / Location',
                              border: const OutlineInputBorder(),
                              errorText: field.errorText,
                              suffixIcon: const Icon(Icons.search),
                            ),
                            child: Text(
                              chosen == null
                                  ? 'Search by name or location'
                                  : '${chosen.name} · ${chosen.location}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: chosen == null
                                  ? TextStyle(
                                      color: Theme.of(context).hintColor,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _issue,
                  decoration: const InputDecoration(
                    labelText: 'Issue type',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Damaged Tombstone',
                            'Overgrown Grass',
                            'Cleanliness',
                            'Other',
                          ]
                          .map(
                            (issue) => DropdownMenuItem(
                              value: issue,
                              child: Text(issue),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _issue = value ?? _issue),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    hintText: 'Describe the issue and where it is.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe the issue'
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  'Photo (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_photoPreview != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _photoPreview!,
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _choosePhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_photo == null ? 'UPLOAD PHOTO' : 'CHANGE PHOTO'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting || graves.isEmpty ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_submitting ? 'SUBMITTING…' : 'SUBMIT REQUEST'),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'My Requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (myRequests.isEmpty)
                  const ListTile(title: Text('No maintenance requests yet.')),
                for (final request in myRequests)
                  Card(
                    child: ListTile(
                      leading: _requestThumbnail(request),
                      title: Text(request.issue),
                      subtitle: Text(
                        '${store.graveById(request.graveId)?.location ?? request.graveId}\n'
                        '${request.status} · ${request.priority} priority · '
                        '${request.createdAt.year}-${request.createdAt.month.toString().padLeft(2, '0')}-${request.createdAt.day.toString().padLeft(2, '0')}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _requestThumbnail(MaintenanceRequest request) {
    final provider = PhotoService.provider(request.photoUrl);
    if (provider == null) return const Icon(Icons.build_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image(
        image: provider,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _GraveSearchDelegate extends SearchDelegate<Grave?> {
  _GraveSearchDelegate(this.graves);

  final List<Grave> graves;

  @override
  String get searchFieldLabel => 'Search grave by name or location';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _matches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _matches(context);

  Widget _matches(BuildContext context) {
    final term = query.trim().toLowerCase();
    final matches = graves.where((grave) {
      return grave.name.toLowerCase().contains(term) ||
          grave.location.toLowerCase().contains(term);
    }).toList();
    if (matches.isEmpty) {
      return Center(child: Text('No graves match “$query”.'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final grave = matches[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(grave.name),
          subtitle: Text(grave.location),
          onTap: () => close(context, grave),
        );
      },
    );
  }
}
