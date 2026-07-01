import 'dart:async';

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'ride_options_screen.dart';

/// Which field the user is currently editing.
enum _Field { pickup, destination }

class DestinationSearchScreen extends ConsumerStatefulWidget {
  /// The user's current location, used to bias autocomplete and prefill pickup.
  final LatLngPoint origin;

  const DestinationSearchScreen({super.key, required this.origin});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _destFocus = FocusNode();

  _Field _active = _Field.destination;
  List<PlaceSuggestion> _suggestions = [];
  bool _busy = false;
  Timer? _debounce;

  LatLngPoint? _pickupPoint;
  LatLngPoint? _dropPoint;

  @override
  void initState() {
    super.initState();
    _pickupPoint = widget.origin;
    _prefillPickup();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  Future<void> _prefillPickup() async {
    try {
      final addr =
          await ref.read(geoGatewayProvider).reverseGeocode(widget.origin);
      if (!mounted) return;
      if (addr.isNotEmpty) {
        _pickupCtrl.text = addr;
        _pickupPoint = widget.origin.copyWith(address: addr);
      } else {
        _pickupCtrl.text = 'Current location';
      }
      setState(() {});
    } catch (_) {
      if (mounted) _pickupCtrl.text = 'Current location';
    }
  }

  void _onChanged(String value, _Field field) {
    _active = field;
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String input) async {
    setState(() => _busy = true);
    try {
      final results = await ref.read(geoGatewayProvider).autocomplete(
            input,
            near: widget.origin,
          );
      if (!mounted) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final resolved =
          await ref.read(geoGatewayProvider).placeDetails(s.placeId);
      final point = resolved.point.copyWith(address: resolved.address);
      if (_active == _Field.pickup) {
        _pickupPoint = point;
        _pickupCtrl.text = resolved.address;
      } else {
        _dropPoint = point;
        _destCtrl.text = resolved.address;
      }
      setState(() => _suggestions = []);
      await _maybeProceed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load place: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _maybeProceed() async {
    final pickup = _pickupPoint;
    final drop = _dropPoint;
    if (pickup == null || drop == null) return;

    setState(() => _busy = true);
    try {
      final route =
          await ref.read(geoGatewayProvider).route(pickup, drop);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RideOptionsScreen(
          pickup: pickup,
          dropoff: drop,
          route: route,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not compute route: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan your trip')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _fieldRow(
                  icon: Icons.my_location_rounded,
                  color: AppColors.primary,
                  controller: _pickupCtrl,
                  hint: 'Pickup location',
                  field: _Field.pickup,
                ),
                const SizedBox(height: 10),
                _fieldRow(
                  icon: Icons.location_on_rounded,
                  color: AppColors.danger,
                  controller: _destCtrl,
                  hint: 'Where to?',
                  field: _Field.destination,
                  focusNode: _destFocus,
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.separated(
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  leading: const Icon(Icons.place_outlined,
                      color: AppColors.inkSoft),
                  title: Text(s.primaryText, style: AppText.title),
                  subtitle: s.secondaryText.isEmpty
                      ? null
                      : Text(s.secondaryText, style: AppText.bodySoft),
                  onTap: () => _pick(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow({
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hint,
    required _Field field,
    FocusNode? focusNode,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onTap: () => _active = field,
            onChanged: (v) => _onChanged(v, field),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
