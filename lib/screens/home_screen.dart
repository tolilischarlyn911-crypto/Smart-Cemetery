import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Models & Auth
import '../models/user_model.dart';
import 'login_screen.dart';

// Import Screens para sa Menu Actions
import 'search_screen.dart';
import 'qr_scanner_screen.dart';
import 'map_navigation_screen.dart';
import 'request_maintenance_screen.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;
  final Function(int) onNavigateTab;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onNavigateTab,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning,';
    }

    if (hour < 17) {
      return 'Good afternoon,';
    }

    return 'Good evening,';
  }

  // ======================================================================
  // IMAGE PICKER FUNCTION
  // ======================================================================
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected image: ${image.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1B4D2E);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F3),

      // DRAWER
      drawer: _buildDrawer(context),

      body: Builder(
        builder: (scaffoldContext) => Column(
          children: [
            // ============================================================
            // HEADER GREEN SECTION
            // ============================================================
            Container(
              padding: EdgeInsets.only(
                top: topPadding + 16,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // ======================================================
                  // TOP BAR
                  // ======================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // MENU BUTTON
                      IconButton(
                        icon: const Icon(
                          Icons.menu,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Scaffold.of(scaffoldContext).openDrawer();
                        },
                      ),

                      // TITLE
                      const Text(
                        'Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // FEEDBACK + NOTIFICATION
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.feedback_outlined,
                              color: Colors.white,
                            ),
                            tooltip: 'Feedback',
                            onPressed: () {
                              _showFeedbackModal(context);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                            ),
                            tooltip: 'Notifications',
                            onPressed: () {
                              _showNotificationsModal(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ======================================================
                  // GREETING + USER NAME + PROFILE ICON
                  // ======================================================
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
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

                      // USER PROFILE ICON
                      GestureDetector(
                        onTap: () => _showProfileOptionsModal(context),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white24,
                              backgroundImage: (user.photoUrl != null &&
                                      user.photoUrl!.isNotEmpty)
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: (user.photoUrl == null ||
                                      user.photoUrl!.isEmpty)
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ======================================================
                  // SEARCH BAR (CLICKABLE)
                  // ======================================================
                  GestureDetector(
                    onTap: () => onNavigateTab(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Search deceased name',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ============================================================
            // MAIN CONTENT (CLICKABLE GRID & QUICK ACTIONS)
            // ============================================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ======================================================
                  // MAIN GRID MENU ICONS (CLICKABLE)
                  // ======================================================
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      // 1. FIND A GRAVE
                      _buildFeatureCard(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Find a Grave',
                        onTap: () => onNavigateTab(1),
                      ),

                      // 2. SCAN QR CODE
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

                      // 3. MAP & NAVIGATION
                      _buildFeatureCard(
                        context,
                        icon: Icons.map_outlined,
                        label: 'Map &\nNavigation',
                        onTap: () => onNavigateTab(2),
                      ),

                      // 4. MY VISITS
                      _buildFeatureCard(
                        context,
                        icon: Icons.favorite_border,
                        label: 'My Visits',
                        onTap: () => _showMyVisitsModal(context),
                      ),

                      // 5. MAINTENANCE REQUEST
                      _buildFeatureCard(
                        context,
                        icon: Icons.build_outlined,
                        label: 'Maintenance\nRequest',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const RequestMaintenanceScreen(),
                            ),
                          );
                        },
                      ),

                      // 6. ANNOUNCEMENTS
                      _buildFeatureCard(
                        context,
                        icon: Icons.campaign_outlined,
                        label: 'Announcements',
                        onTap: () => _showAnnouncementsModal(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ======================================================
                  // BOTTOM QUICK ACTIONS
                  // ======================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickAction(
                        icon: Icons.notifications_active_outlined,
                        label: 'Reminders',
                        onTap: () => _showRemindersModal(context),
                      ),
                      _QuickAction(
                        icon: Icons.article_outlined,
                        label: 'Cemetery\nGuidelines',
                        onTap: () => _showGuidelinesModal(context),
                      ),
                      _QuickAction(
                        icon: Icons.phone_in_talk_outlined,
                        label: 'Emergency\nContacts',
                        onTap: () => _showEmergencyModal(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================================
  // FEATURE CARD WIDGET
  // ======================================================================
  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFF1B4D2E),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================================
  // DRAWER WIDGET
  // ======================================================================
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF1B4D2E),
            ),
            accountName: Text(
              user.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(user.email),
            currentAccountPicture: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showProfileOptionsModal(context);
              },
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                    (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                        ? NetworkImage(user.photoUrl!)
                        : null,
                child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Color(0xFF1B4D2E),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Find a Grave'),
            onTap: () {
              Navigator.pop(context);
              onNavigateTab(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Cemetery Map'),
            onTap: () {
              Navigator.pop(context);
              onNavigateTab(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: const Text('Maintenance Requests'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RequestMaintenanceScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.feedback_outlined,
              color: Color(0xFF1B4D2E),
            ),
            title: const Text('Feedback'),
            onTap: () {
              Navigator.pop(context);
              _showFeedbackModal(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // MODAL DIALOGS
  // ======================================================================
  void _showModal(BuildContext context, String title, List<Widget> children) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(modalContext),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showProfileOptionsModal(BuildContext context) {
    _showModal(context, 'Profile Picture Options', [
      ListTile(
        leading:
            const Icon(Icons.photo_library_outlined, color: Color(0xFF1B4D2E)),
        title: const Text('Choose from Gallery'),
        onTap: () {
          Navigator.pop(context);
          _pickImage(context, ImageSource.gallery);
        },
      ),
      ListTile(
        leading:
            const Icon(Icons.camera_alt_outlined, color: Color(0xFF1B4D2E)),
        title: const Text('Take a Photo'),
        onTap: () {
          Navigator.pop(context);
          _pickImage(context, ImageSource.camera);
        },
      ),
    ]);
  }

  void _showAnnouncementsModal(BuildContext context) {
    _showModal(context, 'Announcements', [
      const ListTile(
        leading: Icon(Icons.campaign, color: Color(0xFF1B4D2E)),
        title: Text('Upcoming Memorial Day Services'),
        subtitle: Text('Gates open extended hours from 6:00 AM to 8:00 PM.'),
      ),
      const ListTile(
        leading: Icon(Icons.cleaning_services, color: Color(0xFF1B4D2E)),
        title: Text('Scheduled Grounds Maintenance'),
        subtitle: Text('Section B grass trimming on Friday morning.'),
      ),
    ]);
  }

  void _showMyVisitsModal(BuildContext context) {
    _showModal(context, 'My Visits History', [
      const ListTile(
        leading: Icon(Icons.history, color: Color(0xFF1B4D2E)),
        title: Text('Plot A-102 (John Doe)'),
        subtitle: Text('Visited: Yesterday, 3:30 PM'),
      ),
    ]);
  }

  void _showRemindersModal(BuildContext context) {
    _showModal(context, 'Reminders', [
      const ListTile(
        leading: Icon(Icons.event_repeat, color: Color(0xFF1B4D2E)),
        title: Text('Annual Maintenance Due'),
        subtitle: Text('Plot B-45 renewal due next month.'),
      ),
    ]);
  }

  void _showGuidelinesModal(BuildContext context) {
    _showModal(context, 'Cemetery Guidelines', [
      const Text(
        '• Visiting hours: 7:00 AM - 6:00 PM Daily\n'
        '• Please keep the grounds clean and use trash bins.\n'
        '• Only fresh flowers permitted in Section A and B.\n'
        '• Keep noise levels respectful.',
      ),
      const SizedBox(height: 10),
    ]);
  }

  void _showEmergencyModal(BuildContext context) {
    _showModal(context, 'Emergency Contacts', [
      const ListTile(
        leading: Icon(Icons.phone, color: Colors.green),
        title: Text('Cemetery Security Office'),
        subtitle: Text('+1 (555) 019-2834'),
      ),
      const ListTile(
        leading: Icon(Icons.local_hospital, color: Colors.red),
        title: Text('First Aid Post'),
        subtitle: Text('+1 (555) 019-5821'),
      ),
    ]);
  }

  void _showNotificationsModal(BuildContext context) {
    _showModal(context, 'Notifications', [
      const ListTile(
        leading: Icon(Icons.check_circle_outline, color: Colors.green),
        title: Text('Maintenance Request Approved'),
        subtitle: Text('Grass trimming for Plot C-12 has been completed.'),
      ),
    ]);
  }

  void _showFeedbackModal(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    int selectedRating = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.feedback_outlined,
                                color: Color(0xFF1B4D2E), size: 25),
                            SizedBox(width: 8),
                            Text('Send Feedback',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B4D2E))),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('How would you rate your experience?',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final int starNumber = index + 1;
                        return IconButton(
                          onPressed: () {
                            setModalState(() {
                              selectedRating = starNumber;
                            });
                          },
                          icon: Icon(
                            starNumber <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFF1B4D2E),
                            size: 34,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    const Text('Your Feedback',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: feedbackController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write your feedback here...',
                        filled: true,
                        fillColor: const Color(0xFFF2F6F3),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1B4D2E), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4D2E),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (selectedRating == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a rating star.'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(modalContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you for your feedback!'),
                            ),
                          );
                        },
                        child: const Text(
                          'Submit Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ======================================================================
// QUICK ACTION WIDGET
// ======================================================================
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1B4D2E),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
