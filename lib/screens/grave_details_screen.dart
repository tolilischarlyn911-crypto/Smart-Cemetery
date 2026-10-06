import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_setup.dart';
import '../services/grave_share.dart';
import '../services/photo_service.dart';

import '../data/cemetery_store.dart';
import 'map_navigation_screen.dart';

class GraveDetailsScreen extends StatelessWidget {
  final String graveId;
  const GraveDetailsScreen({super.key, required this.graveId});

  String _date(DateTime? date) => date == null
      ? 'Not recorded'
      : '${_months[date.month - 1]} ${date.day}, ${date.year}';

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final store = CemeteryStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final grave = store.graveById(graveId);
        if (grave == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Grave Details')),
            body: const Center(
              child: Text('This grave record is unavailable.'),
            ),
          );
        }
        final displayPhotos = <String>{
          if (grave.portraitPhotoUrl != null) grave.portraitPhotoUrl!,
          if (grave.tombPhotoUrl != null) grave.tombPhotoUrl!,
          ...grave.photos,
        }.toList();
        final portrait = PhotoService.provider(grave.portraitPhotoUrl);
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Grave Details'),
              actions: [
                Builder(
                  builder: (shareContext) => IconButton(
                    tooltip: 'Share grave details',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => shareGrave(
                      shareContext,
                      grave,
                      sampleLocation:
                          store.isDemo || FirebaseSetup.useEmulators,
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 40,
                  backgroundImage: portrait,
                  child: portrait == null
                      ? const Icon(Icons.person_outline, size: 40)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(grave.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${_date(grave.born)} – ${_date(grave.died)}'),
                const SizedBox(height: 8),
                Chip(label: Text(grave.location)),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: 'About'),
                    Tab(text: 'Family Message'),
                    Tab(text: 'Photos'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _detail('Born', _date(grave.born), grave.birthplace),
                          _detail('Died', _date(grave.died), grave.deathplace),
                          _detail('Resting Since', _date(grave.buriedAt), ''),
                        ],
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            grave.message.isEmpty
                                ? 'No family message has been added yet.'
                                : grave.message,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      displayPhotos.isEmpty
                          ? const Center(child: Text('No photos uploaded yet.'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: displayPhotos.length,
                              itemBuilder: (_, index) {
                                final provider = PhotoService.provider(
                                  displayPhotos[index],
                                );
                                if (provider == null) {
                                  return const Icon(
                                    Icons.broken_image_outlined,
                                  );
                                }
                                return Image(
                                  image: provider,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                );
                              },
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final visitorId = FirebaseSetup.configured
                            ? FirebaseAuth.instance.currentUser?.uid
                            : 'preview-visitor';
                        if (visitorId == null) return;
                        await store.addVisit(grave.id, visitorId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Visit recorded.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('RECORD VISIT'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MapNavigationScreen(graveId: grave.id),
                        ),
                      ),
                      child: const Text('GET DIRECTIONS'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detail(String title, String date, String place) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(date),
        if (place.isNotEmpty) Text(place),
      ],
    ),
  );
}
