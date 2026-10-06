import 'package:flutter/material.dart';

import 'admin_shell.dart';

/// A visible entry/exit flow for the local web preview. It does not claim to
/// authenticate anyone; Firebase AdminGate handles real administrator access.
class AdminPreviewGate extends StatefulWidget {
  const AdminPreviewGate({super.key});

  @override
  State<AdminPreviewGate> createState() => _AdminPreviewGateState();
}

class _AdminPreviewGateState extends State<AdminPreviewGate> {
  bool _entered = false;

  @override
  Widget build(BuildContext context) {
    if (_entered) {
      return AdminShell(onLogout: () => setState(() => _entered = false));
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Smart Cemetery Admin Preview',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This local preview is available to anyone who can open this page. Changes stay in this browser. Connect Firebase to require an administrator login and share records across devices.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => setState(() => _entered = true),
                    child: const Text('OPEN ADMIN PREVIEW'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
