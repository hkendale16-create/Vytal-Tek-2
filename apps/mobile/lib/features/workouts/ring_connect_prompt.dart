import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/app_session_controller.dart';

const _ringPromptDismissedKey = 'vytal.ring_prompt.dismissed.v1';
const _ringPromptShownKey = 'vytal.ring_prompt.shown.v1';

/// Offer ring pairing after a saved workout — once, when no device is linked.
Future<void> maybeOfferRingConnect({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final session = ref.read(appSessionProvider);
  if (session.pairedDevice != null) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_ringPromptDismissedKey) == true) return;
  if (prefs.getBool(_ringPromptShownKey) == true) return;
  if (!context.mounted) return;

  await prefs.setBool(_ringPromptShownKey, true);
  if (!context.mounted) return;

  final choice = await showDialog<_RingPromptChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unlock live heart rate'),
      content: const Text(
        'Nice session. Connect a Vytal ring to light live HR during workouts. '
        'App-Only still works anytime — we never invent vitals.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _RingPromptChoice.never),
          child: const Text("Don't ask again"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _RingPromptChoice.later),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _RingPromptChoice.connect),
          child: const Text('Connect'),
        ),
      ],
    ),
  );

  if (choice == _RingPromptChoice.never) {
    await prefs.setBool(_ringPromptDismissedKey, true);
  }
  if (choice == _RingPromptChoice.connect && context.mounted) {
    context.push('/devices');
  }
}

enum _RingPromptChoice { connect, later, never }
