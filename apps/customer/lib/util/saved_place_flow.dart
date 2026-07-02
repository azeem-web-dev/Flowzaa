import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/destination_search_screen.dart';

/// Emoji for a saved-place chip based on its label.
String savedPlaceEmoji(String label) {
  switch (label.toLowerCase()) {
    case 'home':
      return '🏠';
    case 'work':
      return '💼';
    default:
      return '📍';
  }
}

/// Full "add a saved place" flow: pick a place (search or map), ask for a
/// label (Home / Work / custom), then persist it on the user profile.
/// Returns true if a place was saved.
Future<bool> addSavedPlaceFlow(
  BuildContext context,
  WidgetRef ref,
  LatLngPoint origin,
) async {
  final resolved = await Navigator.of(context).push<ResolvedPlace>(
    MaterialPageRoute(
      builder: (_) => DestinationSearchScreen(origin: origin, pickMode: true),
    ),
  );
  if (resolved == null || !context.mounted) return false;

  final label = await promptSavedPlaceLabel(context);
  if (label == null || !context.mounted) return false;

  final profile = ref.read(userProfileProvider).value;
  final places = [
    ...(profile?.savedPlaces ?? const <SavedPlace>[])
        .where((p) => p.label.toLowerCase() != label.toLowerCase()),
    SavedPlace(
      label: label,
      address: resolved.address,
      lat: resolved.point.lat,
      lng: resolved.point.lng,
    ),
  ];
  try {
    await ref.read(authServiceProvider).saveSavedPlaces(places);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label saved')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save place: $e')),
      );
    }
    return false;
  }
}

/// Asks the user to label a place: Home / Work / a custom name.
Future<String?> promptSavedPlaceLabel(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Save place as'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop('Home'),
          child: const Row(
            children: [
              Text('🏠', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text('Home', style: AppText.title),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop('Work'),
          child: const Row(
            children: [
              Text('💼', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text('Work', style: AppText.title),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () async {
            final custom = await _promptCustomLabel(ctx);
            if (ctx.mounted) Navigator.of(ctx).pop(custom);
          },
          child: const Row(
            children: [
              Text('📍', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text('Other…', style: AppText.title),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<String?> _promptCustomLabel(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Name this place'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Gym, College'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            Navigator.of(ctx).pop(v.isEmpty ? null : v);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
