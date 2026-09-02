import 'package:flutter/material.dart';

class RequestMaintenanceScreen extends StatefulWidget {
  const RequestMaintenanceScreen({super.key});

  @override
  State<RequestMaintenanceScreen> createState() =>
      _RequestMaintenanceScreenState();
}

class _RequestMaintenanceScreenState extends State<RequestMaintenanceScreen> {
  String selectedGrave = 'Block 12 - Lot 45 - Grave 3';
  String selectedIssue = 'Damaged Tombstone';
  final TextEditingController _descController = TextEditingController(
    text: 'The tombstone is broken on the left side.',
  );

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Maintenance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grave / Location',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedGrave,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
              items: ['Block 12 - Lot 45 - Grave 3']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedGrave = val);
              },
            ),
            const SizedBox(height: 16),
            const Text('Issue Type',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedIssue,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
              items: ['Damaged Tombstone', 'Overgrown Grass', 'Cleanliness']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedIssue = val);
              },
            ),
            const SizedBox(height: 16),
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Upload Photo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    image: const DecorationImage(
                      image: NetworkImage(
                          'https://images.unsplash.com/photo-1509021436483-2070387532fa?auto=format&fit=crop&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.grey),
                )
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4D2E),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Maintenance Request Submitted!')),
                  );
                },
                child: const Text('SUBMIT REQUEST',
                    style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
