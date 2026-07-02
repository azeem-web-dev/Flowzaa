import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../util/saved_place_flow.dart';
import '../widgets/tinted_circle_icon.dart';
import 'history_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header card: avatar, name (editable), phone, rating.
          FadeSlideIn(
              child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _initial(profile?.name),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile?.name ?? 'Rider',
                              style: AppText.h2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_rounded,
                                size: 18, color: AppColors.inkSoft),
                            onPressed: () =>
                                _editName(context, ref, profile?.name ?? ''),
                          ),
                        ],
                      ),
                      Text(
                        profile == null ? '—' : Fmt.phone(profile.phone),
                        style: AppText.bodySoft,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RatingStars(value: profile?.rating ?? 5, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            (profile?.rating ?? 5.0).toStringAsFixed(1),
                            style: AppText.label,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),

          _tile(
            index: 1,
            icon: Icons.history_rounded,
            title: 'Ride history',
            subtitle: 'Your past trips and receipts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          _tile(
            index: 2,
            icon: Icons.bookmark_rounded,
            title: 'Saved places',
            subtitle: 'Home, Work and other shortcuts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SavedPlacesScreen()),
            ),
          ),
          _tile(
            index: 3,
            icon: Icons.info_outline_rounded,
            title: 'About Flowzaa',
            subtitle: 'Zero commission, always',
            onTap: () => _showAbout(context),
          ),
          _tile(
            index: 4,
            icon: Icons.logout_rounded,
            title: 'Sign out',
            color: AppColors.danger,
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  static String _initial(String? name) {
    final n = (name ?? '').trim();
    return n.isEmpty ? 'R' : n[0].toUpperCase();
  }

  Widget _tile({
    required int index,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 50 * index),
      child: ScaleTap(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.line),
          ),
          child: ListTile(
            leading: TintedCircleIcon(
              icon: icon,
              color: color ?? AppColors.primary,
            ),
            title: Text(
              title,
              style: AppText.title.copyWith(color: color ?? AppColors.ink),
            ),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: AppText.bodySoft),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.inkSoft),
          ),
        ),
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Full name'),
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
    if (name == null || name == current) return;
    try {
      await ref.read(authServiceProvider).updateName(name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update name: $e')),
        );
      }
    }
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Flowzaa'),
        content: const Text(
          'Flowzaa takes 0% commission — you pay your captain directly.',
          style: AppText.body,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need an OTP to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Pop back to the root so AuthGate can swap to the login flow.
    Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(authServiceProvider).signOut();
  }
}

/// Manage saved places: list, delete, add new via the place picker.
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final places = profile?.savedPlaces ?? const <SavedPlace>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add place'),
      ),
      body: places.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 64, color: AppColors.inkSoft),
                  SizedBox(height: 12),
                  Text('No saved places', style: AppText.h2),
                  SizedBox(height: 4),
                  Text('Add Home, Work and more for one-tap rides.',
                      style: AppText.bodySoft),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: places.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
              itemBuilder: (_, i) {
                final p = places[i];
                return FadeSlideIn(
                  delay: Duration(milliseconds: 50 * i),
                  child: ListTile(
                    leading: TintedCircleIcon(
                      icon: savedPlaceIcon(p.label),
                      color: AppColors.primary,
                    ),
                    title: Text(p.label, style: AppText.title),
                    subtitle: Text(
                      p.address,
                      style: AppText.bodySoft,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger),
                      onPressed: () => _delete(context, ref, places, p),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    var origin = const LatLngPoint(lat: 17.44, lng: 78.39);
    try {
      origin = await ref.read(locationServiceProvider).currentPosition();
    } catch (_) {
      // Fall back to the default city centre.
    }
    if (!context.mounted) return;
    await addSavedPlaceFlow(context, ref, origin);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<SavedPlace> places,
    SavedPlace place,
  ) async {
    final remaining = places.where((p) => p != place).toList();
    try {
      await ref.read(authServiceProvider).saveSavedPlaces(remaining);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${place.label} removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove place: $e')),
        );
      }
    }
  }
}
