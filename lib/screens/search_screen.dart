import 'package:flutter/material.dart';

import '../data/cemetery_store.dart';
import 'grave_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = CemeteryStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Grave')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              autofocus: false,
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                hintText: 'Search by name or location',
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  final results = store.search(query);
                  if (results.isEmpty) {
                    return Center(child: Text(query.isEmpty
                        ? 'No burial records available yet.'
                        : 'No graves match “$query”.'));
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final grave = results[index];
                      return Semantics(
                        identifier: 'grave-${grave.id}',
                        child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(grave.name),
                          subtitle: Text(grave.location),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GraveDetailsScreen(graveId: grave.id),
                            ),
                          ),
                        ),
                      ));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
