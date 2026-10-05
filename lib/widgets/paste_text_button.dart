import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PasteTextButton extends StatelessWidget {
  const PasteTextButton({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  Future<void> _paste(BuildContext context) async {
    try {
      final text = (await Clipboard.getData('text/plain'))?.text;
      if (text == null || text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('There is no text to paste.')),
          );
        }
        return;
      }
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the clipboard.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Paste $label',
    icon: const Icon(Icons.content_paste_outlined),
    onPressed: () => _paste(context),
  );
}
