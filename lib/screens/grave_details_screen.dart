import 'package:flutter/material.dart';
import 'map_navigation_screen.dart';

class GraveDetailsScreen extends StatelessWidget {
  const GraveDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grave Details'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=33'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pedro Dela Cruz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'May 12, 1940 - March 3, 2020',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECE9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Block 12 - Lot 45 - Grave 3',
                style: TextStyle(
                  color: Color(0xFF1B4D2E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const TabBar(
              labelColor: Color(0xFF1B4D2E),
              indicatorColor: Color(0xFF1B4D2E),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'About'),
                Tab(text: 'Family Message'),
                Tab(text: 'Photos'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Born',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'May 12, 1940\nManila, Philippines',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Died',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'March 3, 2020\nQuezon City, Philippines',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Resting Since',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'March 5, 2020',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Center(child: Text('Always in our hearts.')),
                  Center(child: Text('No photos uploaded yet.')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4D2E),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapNavigationScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'GET DIRECTIONS',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
