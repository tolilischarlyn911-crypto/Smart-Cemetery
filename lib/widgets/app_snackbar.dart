import 'package:flutter/material.dart';

/// One place for feedback toasts so every screen looks the same:
/// green for success, red (and longer-lived) for errors.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : const Color(0xFF1B4D2E),
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
}
