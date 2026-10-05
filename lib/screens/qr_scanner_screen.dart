import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/cemetery_store.dart';
import '../models/cemetery_models.dart';
import 'grave_details_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _opening = false;
  bool _choosingImage = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(
    BarcodeCapture capture, {
    bool fromGallery = false,
  }) async {
    if (_opening ||
        (_choosingImage && !fromGallery) ||
        capture.barcodes.isEmpty) {
      return;
    }
    final value = capture.barcodes.first.rawValue;
    final id = value == null ? null : Grave.idFromQr(value);
    if (id == null) {
      setState(() => _message = 'This is not a Smart Cemetery grave code.');
      return;
    }
    final grave = CemeteryStore.instance.graveById(id);
    if (grave == null || grave.status != 'occupied') {
      setState(() => _message = 'No memorial was found for this code.');
      return;
    }
    _opening = true;
    await _controller.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GraveDetailsScreen(graveId: id)),
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _message = null;
    });
    await _controller.start();
  }

  Future<void> _scanFromPhoto() async {
    if (_opening || _choosingImage) return;
    setState(() => _choosingImage = true);
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (photo == null || !mounted) return;
      final result = await _controller.analyzeImage(
        photo.path,
        formats: const [BarcodeFormat.qrCode],
      );
      if (!mounted) return;
      if (result == null || result.barcodes.isEmpty) {
        setState(() => _message = 'No QR code was found in this photo.');
        return;
      }
      await _onDetect(result, fromGallery: true);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not scan this photo: $error');
      }
    } finally {
      if (mounted) setState(() => _choosingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            icon: const Icon(Icons.flash_on),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Camera unavailable: ${error.errorDetails?.message ?? error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _message ?? 'Align the QR code within the frame to scan',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _choosingImage ? null : _scanFromPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('SCAN FROM PHOTO'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
