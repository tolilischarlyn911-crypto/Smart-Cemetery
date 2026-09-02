import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;
  final Function(int) onNavigateTab;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1B4D2E);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F3),
      body: Column(
        children: [
          // Header Green Section
          Container(
            padding:
                const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.menu, color: Colors.white),
                    Text(
                      'Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.notifications_none, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Good morning,',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          NetworkImage('https://i.pravatar.cc/150?img=12'),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                // Search Input inside header
                GestureDetector(
                  onTap: () => onNavigateTab(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Search deceased name',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Spacer(),
                        Icon(Icons.search, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Grid Menu Icons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.location_on_outlined,
                      label: 'Find a Grave',
                      onTap: () => onNavigateTab(1),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.qr_code_scanner,
                      label: 'Scan QR Code',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QrScannerScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.map_outlined,
                      label: 'Map &\nNavigation',
                      onTap: () => onNavigateTab(2),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.favorite_border,
                      label: 'My Visits',
                      onTap: () {},
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.build_outlined,
                      label: 'Maintenance\nRequest',
                      onTap: () => onNavigateTab(3),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.campaign_outlined,
                      label: 'Announcements',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom Row Direct Navigation Items
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _QuickAction(
                      icon: Icons.notifications_active_outlined,
                      label: 'Reminders',
                    ),
                    _QuickAction(
                      icon: Icons.article_outlined,
                      label: 'Cemetery\nGuidelines',
                    ),
                    _QuickAction(
                      icon: Icons.phone_in_talk_outlined,
                      label: 'Emergency\nContacts',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1B4D2E), size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickAction({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1B4D2E), size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
