import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../subscription/legal_links.dart';
import '../shared/health_ui.dart';

/// Phase G — auto-renew disclosure + Privacy / Terms links for store review.
class SubscriptionLegalFooter extends StatelessWidget {
  const SubscriptionLegalFooter({super.key, this.expanded = true});

  final bool expanded;

  Future<void> _open(BuildContext context, Uri uri, String label) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $label')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expanded) ...[
            Text(
              SubscriptionDisclosure.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              SubscriptionDisclosure.body,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ] else
            Text(
              SubscriptionDisclosure.shortFooter,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          if (expanded) const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () =>
                    _open(context, VytalLegalLinks.privacyUri, 'Privacy Policy'),
                child: const Text('Privacy Policy'),
              ),
              TextButton(
                onPressed: () =>
                    _open(context, VytalLegalLinks.termsUri, 'Terms of Use'),
                child: const Text('Terms of Use'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
