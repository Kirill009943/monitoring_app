import 'package:flutter/material.dart';

import '../../core/help_content.dart';

Future<void> showHelpSheet(BuildContext context, String pageId) {
  final entries = HelpContent.pages[pageId] ?? const <HelpEntry>[];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Help', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          for (final e in entries) ...[
            Text(e.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(e.body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
}

class HelpButton extends StatelessWidget {
  final String pageId;

  const HelpButton({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.help_outline),
        tooltip: 'Help for this page',
        onPressed: () => showHelpSheet(context, pageId),
      );
}
