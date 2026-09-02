import 'package:flutter/material.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isFlashOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() {
                _isFlashOn = !_isFlashOn;
              });
            },
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1593100126453-19b562a800c1?auto=format&fit=crop&q=80',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            bottom: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align the QR code within the frame to scan',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
