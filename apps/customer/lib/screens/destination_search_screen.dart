import 'dart:async';

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/tinted_circle_icon.dart';
import 'pick_on_map_screen.dart';
import 'ride_options_screen.dart';

/// Which field the user is currently editing.
enum _Field { pickup, destination }

class DestinationSearchScreen extends ConsumerStatefulWidget {
  /// The user's current location, used to bias autocomplete and prefill pickup.
  final LatLngPoint origin;

  /// Preselects this ride type on the options screen (home shortcut chips).
  final VehicleType? preselectType;

  /// When true the screen is a plain place picker: choosing a destination
  /// pops with a [ResolvedPlace] instead of routing to ride options.
  final bool pickMode;

  const DestinationSearchScreen({
    super.key,
    required this.origin,
    this.preselectType,
    this.pickMode = false,
  });

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
  bool _loadingSuggestions = false;
  Timer? _debounce;

  LatLngPoint? _pickupPoint;
  LatLngPoint? _dropPoint;

  @override
  void initState() {
    super.initState();
    _pickupPoint = widget.origin;
    if (!widget.pickMode) _prefillPickup();
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
    setState(() {
      _busy = true;
      _loadingSuggestions = true;
    });
    try {
      // Bias results near the user's current location.
      final results = await ref.read(geoGatewayProvider).autocomplete(
            input,
            near: widget.origin,
          );
      if (!mounted) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _pick(PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final resolved =
          await ref.read(geoGatewayProvider).placeDetails(s.placeId);
      if (!mounted) return;
      _applyResolved(resolved);
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

  /// Fills the active field with [resolved]; in pick mode this pops instead.
  void _applyResolved(ResolvedPlace resolved) {
    if (widget.pickMode && _active == _Field.destination) {
      Navigator.of(context).pop(resolved);
      return;
    }
    final point = resolved.point.copyWith(address: resolved.address);
    if (_active == _Field.pickup) {
      _pickupPoint = point;
      _pickupCtrl.text = resolved.address;
    } else {
      _dropPoint = point;
      _destCtrl.text = resolved.address;
    }
    setState(() => _suggestions = []);
    _maybeProceed();
  }

  Future<void> _chooseOnMap(_Field field) async {
    FocusScope.of(context).unfocus();
    _active = field;
    final initial =
        (field == _Field.pickup ? _pickupPoint : _dropPoint) ?? widget.origin;
    final resolved = await Navigator.of(context).push<ResolvedPlace>(
      MaterialPageRoute(
        builder: (_) => PickOnMapScreen(
          initial: initial,
          title: field == _Field.pickup ? 'Set pickup' : 'Set destination',
        ),
      ),
    );
    if (resolved == null || !mounted) return;
    _applyResolved(resolved);
  }

  /// Resets the pickup to the user's current GPS location.
  Future<void> _useCurrentLocation() async {
    FocusScope.of(context).unfocus();
    _active = _Field.pickup;
    _pickupPoint = widget.origin;
    _pickupCtrl.text = 'Current location';
    setState(() => _suggestions = []);
    await _prefillPickup();
    await _maybeProceed();
  }

  Future<void> _maybeProceed() async {
    final pickup = _pickupPoint;
    final drop = _dropPoint;
    if (pickup == null || drop == null) return;

    setState(() => _busy = true);
    try {
      final route = await ref.read(geoGatewayProvider).route(pickup, drop);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RideOptionsScreen(
          pickup: pickup,
          dropoff: drop,
          route: route,
          initialType: widget.preselectType,
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
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Choose a place' : 'Plan your trip'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                if (!widget.pickMode) ...[
                  _fieldRow(
                    icon: Icons.my_location_rounded,
                    color: AppColors.primary,
                    controller: _pickupCtrl,
                    hint: 'Pickup location',
                    field: _Field.pickup,
                  ),
                  const SizedBox(height: 10),
                ],
                _fieldRow(
                  icon: Icons.location_on_rounded,
                  color: AppColors.danger,
                  controller: _destCtrl,
                  hint: widget.pickMode ? 'Search for a place' : 'Where to?',
                  field: _Field.destination,
                  focusNode: _destFocus,
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loadingSuggestions && _suggestions.isEmpty
                ? _suggestionShimmer()
                : _suggestions.isEmpty
                    ? _shortcutTiles()
                    : _suggestionList(),
          ),
        ],
      ),
    );
  }

  Widget _suggestionList() {
    return ListView.separated(
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
      itemBuilder: (_, i) {
        final s = _suggestions[i];
        final tile = ScaleTap(
          onTap: () => _pick(s),
          child: ListTile(
            leading: const TintedCircleIcon(
              icon: Icons.place_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              s.primaryText,
              style: AppText.title.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: s.secondaryText.isEmpty
                ? null
                : Text(s.secondaryText, style: AppText.bodySoft),
          ),
        );
        if (i >= 8) return tile;
        return FadeSlideIn(
          delay: Duration(milliseconds: 40 * i),
          duration: const Duration(milliseconds: 260),
          child: tile,
        );
      },
    );
  }

  /// Skeleton rows shown while suggestions are being fetched.
  Widget _suggestionShimmer() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                ShimmerBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 180, height: 14),
                      const SizedBox(height: 8),
                      ShimmerBox(
                        width: double.infinity,
                        height: 12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Shown while there are no suggestions: map-pick and GPS shortcuts.
  Widget _shortcutTiles() {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text('QUICK OPTIONS', style: AppText.label),
        ),
        if (!widget.pickMode) ...[
          ScaleTap(
            onTap: () => _chooseOnMap(_Field.pickup),
            child: const ListTile(
              leading: TintedCircleIcon(
                icon: Icons.pin_drop_rounded,
                color: AppColors.accent,
              ),
              title: Text('Choose pickup on map', style: AppText.title),
              subtitle:
                  Text('Drop a pin at your pickup', style: AppText.bodySoft),
            ),
          ),
          const Divider(height: 1, indent: 68),
          ScaleTap(
            onTap: _useCurrentLocation,
            child: const ListTile(
              leading: TintedCircleIcon(
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
              ),
              title: Text('Use current location', style: AppText.title),
              subtitle:
                  Text('Set pickup to where you are', style: AppText.bodySoft),
            ),
          ),
          const Divider(height: 1, indent: 68),
        ],
        ScaleTap(
          onTap: () => _chooseOnMap(_Field.destination),
          child: ListTile(
            leading: const TintedCircleIcon(
              icon: Icons.map_rounded,
              color: AppColors.info,
            ),
            title: Text(
              widget.pickMode ? 'Choose on map' : 'Choose destination on map',
              style: AppText.title,
            ),
            subtitle:
                const Text('Drop a pin on the map', style: AppText.bodySoft),
          ),
        ),
      ],
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
