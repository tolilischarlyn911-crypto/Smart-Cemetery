import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/cemetery_store.dart';
import '../services/photo_service.dart';
import '../services/payment_reminder_service.dart';
import '../services/profile_photo_service.dart';

// Models & Auth
import '../models/user_model.dart';

// Import Screens para sa Menu Actions
import 'qr_scanner_screen.dart';
import 'request_maintenance_screen.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;
  final Function(int) onNavigateTab;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onNavigateTab,
    required this.onLogout,
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

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final image = await PhotoService.pick(source);
      if (image != null) {
        await ProfilePhotoService.save(user.uid ?? 'preview-visitor', image);
      }
      if (image != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1B4D2E);
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
                          icon: const Icon(Icons.menu, color: Colors.white),
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
                        Expanded(
                          child: Column(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // USER PROFILE ICON
                        GestureDetector(
                          onTap: () => _showProfileOptionsModal(context),
                          child: Stack(
                            children: [
                              ValueListenableBuilder<String?>(
                                valueListenable: ProfilePhotoService.source,
                                builder: (context, source, _) {
                                  final image = PhotoService.provider(
                                    source ?? user.photoUrl,
                                  );
                                  return CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: image,
                                    child: image == null
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
                                  );
                                },
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
                      primary: false,
                      padding: EdgeInsets.zero,
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

                        // 7. REMINDERS
                        _buildFeatureCard(
                          context,
                          icon: Icons.notifications_active_outlined,
                          label: 'Reminders',
                          onTap: () => _showRemindersModal(context),
                        ),

                        // 8. CEMETERY GUIDELINES
                        _buildFeatureCard(
                          context,
                          icon: Icons.article_outlined,
                          label: 'Cemetery\nGuidelines',
                          onTap: () => _showGuidelinesModal(context),
                        ),

                        // 9. EMERGENCY CONTACTS
                        _buildFeatureCard(
                          context,
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

  // ======================================================================
  // DRAWER WIDGET
  // ======================================================================
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1B4D2E)),
            accountName: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user.email),
            currentAccountPicture: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showProfileOptionsModal(context);
              },
              child: ValueListenableBuilder<String?>(
                valueListenable: ProfilePhotoService.source,
                builder: (context, source, _) {
                  final image = PhotoService.provider(source ?? user.photoUrl);
                  return CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: image,
                    child: image == null
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF1B4D2E),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                },
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
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              onLogout();
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
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(modalContext),
                ),
              ],
            ),
            const Divider(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(modalContext).height * 0.55,
              ),
              child: ListView(shrinkWrap: true, children: children),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileOptionsModal(BuildContext context) {
    _showModal(context, 'Profile Picture Options', [
      ListTile(
        leading: const Icon(
          Icons.photo_library_outlined,
          color: Color(0xFF1B4D2E),
        ),
        title: const Text('Choose from Gallery'),
        onTap: () {
          Navigator.pop(context);
          _pickImage(context, ImageSource.gallery);
        },
      ),
      ListTile(
        leading: const Icon(
          Icons.camera_alt_outlined,
          color: Color(0xFF1B4D2E),
        ),
        title: const Text('Take a Photo'),
        onTap: () {
          Navigator.pop(context);
          _pickImage(context, ImageSource.camera);
        },
      ),
    ]);
  }

  void _showAnnouncementsModal(BuildContext context) {
    final items = CemeteryStore.instance.recentAnnouncements;
    _showModal(context, 'Announcements', [
      if (items.isEmpty) const ListTile(title: Text('No announcements yet.')),
      for (final item in items)
        ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: Text('${item['title'] ?? ''}'),
          subtitle: Text('${item['body'] ?? ''}'),
        ),
    ]);
  }

  void _showMyVisitsModal(BuildContext context) {
    final visitorId = user.uid ?? 'preview-visitor';
    final visits = CemeteryStore.instance.visitsForVisitor(visitorId);
    _showModal(context, 'My Visits History', [
      if (visits.isEmpty)
        const ListTile(title: Text('No visits recorded yet.')),
      for (final visit in visits)
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(
            CemeteryStore.instance.graveById('${visit['graveId']}')?.name ??
                'Grave',
          ),
          subtitle: Text(_visitDate(visit['date'])),
        ),
    ]);
  }

  void _showRemindersModal(BuildContext context) {
    final visitorId = user.uid ?? 'preview-visitor';
    final payments =
        CemeteryStore.instance.payments
            .where(
              (payment) =>
                  payment.ownerId == visitorId && payment.status != 'Paid',
            )
            .toList()
          ..sort(
            (a, b) => (a.dueDate ?? DateTime(9999)).compareTo(
              b.dueDate ?? DateTime(9999),
            ),
          );
    _showModal(context, 'Reminders', [
      if (PaymentReminderService.supported)
        FutureBuilder<bool>(
          future: PaymentReminderService.instance.isEnabled(visitorId),
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Phone payment alerts'),
              subtitle: const Text(
                'Get an alert 7 days before and on the due date.',
              ),
              trailing: TextButton(
                onPressed: snapshot.hasData
                    ? () async {
                        try {
                          if (enabled) {
                            await PaymentReminderService.instance.disable(
                              visitorId,
                            );
                          } else {
                            final granted = await PaymentReminderService
                                .instance
                                .enable(
                                  visitorId,
                                  List.of(CemeteryStore.instance.payments),
                                );
                            if (!granted) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Allow notifications in device settings to receive payment alerts.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  enabled
                                      ? 'Phone payment alerts turned off.'
                                      : 'Phone payment alerts enabled.',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not update alerts: $error',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: Text(enabled ? 'TURN OFF' : 'ENABLE'),
              ),
            );
          },
        ),
      if (payments.isEmpty)
        const ListTile(
          title: Text('No unpaid payments linked to this account.'),
        ),
      for (final payment in payments)
        ListTile(
          leading: Icon(
            payment.dueDate != null && payment.dueDate!.isBefore(DateTime.now())
                ? Icons.warning_amber_rounded
                : Icons.event_note_outlined,
            color: const Color(0xFF1B4D2E),
          ),
          title: Text(
            '${payment.type} · ₱${payment.amount.toStringAsFixed(2)}',
          ),
          subtitle: Text(
            payment.dueDate == null
                ? 'Ask the cemetery office for the due date.'
                : '${payment.dueDate!.isBefore(DateTime.now()) ? 'Overdue' : 'Due'} '
                      '${_shortDate(payment.dueDate!)} · ${payment.status}',
          ),
        ),
    ]);
  }

  String _shortDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _visitDate(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return 'Visit date unavailable';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Visited ${_shortDate(date)} at $hour:$minute';
  }

  void _showGuidelinesModal(BuildContext context) {
    final settings = CemeteryStore.instance.settings;
    _showModal(context, 'Cemetery Guidelines', [
      ListTile(
        title: const Text('Visiting hours'),
        subtitle: Text(
          '${settings['visitingHours'] ?? 'Contact the cemetery office.'}',
        ),
      ),
      ListTile(
        title: const Text('Guidelines'),
        subtitle: Text(
          '${settings['guidelines'] ?? 'Contact the cemetery office.'}',
        ),
      ),
    ]);
  }

  void _showEmergencyModal(BuildContext context) {
    final contact = CemeteryStore.instance.settings['emergencyContact'];
    final contactText = contact is String ? contact.trim() : '';
    String? phone;
    for (final match in RegExp(r'\+?\d[\d\s().-]*\d').allMatches(contactText)) {
      final candidate = match.group(0)!.replaceAll(RegExp(r'[^\d+]'), '');
      final digitCount = candidate.replaceAll('+', '').length;
      if (digitCount >= 3 && digitCount <= 15) {
        phone = candidate;
        break;
      }
    }
    _showModal(context, 'Emergency Contacts', [
      ListTile(
        leading: const Icon(Icons.phone, color: Colors.green),
        title: const Text('Emergency contact'),
        subtitle: Text(
          contactText.isEmpty
              ? 'Contact local emergency services.'
              : contactText,
        ),
        trailing: phone == null ? null : const Icon(Icons.call_outlined),
        onTap: phone == null
            ? null
            : () async {
                try {
                  final opened = await launchUrl(
                    Uri(scheme: 'tel', path: phone),
                    mode: LaunchMode.externalApplication,
                  );
                  if (opened || !context.mounted) return;
                } catch (_) {
                  if (!context.mounted) return;
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the phone dialer.'),
                    ),
                  );
                }
              },
      ),
    ]);
  }

  void _showNotificationsModal(BuildContext context) {
    final store = CemeteryStore.instance;
    final visitorId = user.uid ?? 'preview-visitor';
    final announcements = store.recentAnnouncements;
    final requests = store.recentRequests
        .where((request) => request.requestedBy == visitorId)
        .toList();
    _showModal(context, 'Notifications', [
      if (announcements.isEmpty && requests.isEmpty)
        const ListTile(title: Text('No updates yet.')),
      if (announcements.isNotEmpty)
        const ListTile(title: Text('Announcements')),
      for (final announcement in announcements)
        ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: Text('${announcement['title'] ?? 'Announcement'}'),
          subtitle: Text('${announcement['body'] ?? ''}'),
        ),
      if (requests.isNotEmpty)
        const ListTile(title: Text('Maintenance updates')),
      for (final request in requests.take(5))
        ListTile(
          leading: const Icon(Icons.build_outlined),
          title: Text('${request.issue} · ${request.status}'),
          subtitle: Text(
            store.graveById(request.graveId)?.location ?? request.graveId,
          ),
        ),
    ]);
  }

  void _showFeedbackModal(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    int selectedRating = 0;
    bool submitting = false;

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
                            Icon(
                              Icons.feedback_outlined,
                              color: Color(0xFF1B4D2E),
                              size: 25,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Send Feedback',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B4D2E),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'How would you rate your experience?',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
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
                    const Text(
                      'Your Feedback',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                            color: Color(0xFF1B4D2E),
                            width: 1.5,
                          ),
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
                        onPressed: submitting
                            ? null
                            : () async {
                                if (selectedRating == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select a rating star.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => submitting = true);
                                try {
                                  await CemeteryStore.instance.addFeedback(
                                    userId: user.uid ?? 'preview-visitor',
                                    rating: selectedRating,
                                    message: feedbackController.text,
                                  );
                                  if (!modalContext.mounted) return;
                                  Navigator.pop(modalContext);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Feedback submitted.'),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (modalContext.mounted) {
                                    ScaffoldMessenger.of(
                                      modalContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not send feedback: $error',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (modalContext.mounted) {
                                    setModalState(() => submitting = false);
                                  }
                                }
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
    ).whenComplete(feedbackController.dispose);
  }
}
