import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import 'trip_complete_screen.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  final MapController _mapController = MapController();
  final _pinController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _mapController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(activeRideProvider);

    // When the ride completes, move to the completion screen.
    ref.listen(activeRideProvider, (prev, next) {
      final ride = next.valueOrNull;
      final prevRide = prev?.valueOrNull;
      // Ride resolved to null (completed/cancelled) → pop back home.
      if (ride == null && prevRide != null) {
        if (prevRide.status == RideStatus.completed) {
          _goToComplete(prevRide);
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    return rideAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (ride) {
        if (ride == null) {
          // No active ride — nothing to show.
          return const Scaffold(
            body: Center(child: Text('No active ride')),
          );
        }
        if (ride.status == RideStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _goToComplete(ride);
          });
        }
        return _buildRide(ride);
      },
    );
  }

  void _goToComplete(Ride ride) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TripCompleteScreen(ride: ride)),
    );
  }

  Widget _buildRide(Ride ride) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            _statusBar(ride),
            Expanded(child: _map(ride)),
            _actionCard(ride),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(Ride ride) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: AppColors.primary,
      child: Text(
        ride.status.captainLabel,
        textAlign: TextAlign.center,
        style: AppText.title.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _map(Ride ride) {
    final polyline = ride.routePolyline;
    final points = <LatLng>[];
    if (polyline != null && polyline.isNotEmpty) {
      points.addAll(decodeToLatLng(polyline));
    }

    // Show the leg relevant to the current stage.
    final target = ride.status == RideStatus.ongoing
        ? ride.dropoff.toLatLng
        : ride.pickup.toLatLng;

    final markers = <Marker>[
      Marker(
        point: ride.pickup.toLatLng,
        width: 44,
        height: 44,
        child: const Icon(Icons.trip_origin,
            color: AppColors.success, size: 32),
      ),
      Marker(
        point: ride.dropoff.toLatLng,
        width: 44,
        height: 44,
        child: const Icon(Icons.location_on, color: AppColors.danger, size: 36),
      ),
      if (ride.captainLocation != null)
        Marker(
          point: ride.captainLocation!.toLatLng,
          width: 44,
          height: 44,
          child: const Icon(Icons.two_wheeler,
              color: AppColors.primary, size: 34),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: target,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.flowzaa.captain',
        ),
        if (points.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: AppColors.primary,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _actionCard(Ride ride) {
    switch (ride.status) {
      case RideStatus.accepted:
        return _acceptedCard(ride);
      case RideStatus.arrived:
        return _arrivedCard(ride);
      case RideStatus.ongoing:
        return _ongoingCard(ride);
      default:
        return const SizedBox.shrink();
    }
  }

  BoxDecoration get _cardDecoration => const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16),
        ],
      );

  Widget _acceptedCard(Ride ride) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _riderRow(ride),
          const SizedBox(height: 14),
          _addressTile(Icons.trip_origin, AppColors.primary, 'PICKUP',
              ride.pickup.address ?? 'Pickup point'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateTo(ride.pickup),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(ride),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: "I've Arrived",
            icon: Icons.check_circle_outline,
            loading: _busy,
            onPressed: () => _markArrived(ride),
          ),
        ],
      ),
    );
  }

  Widget _arrivedCard(Ride ride) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _riderRow(ride),
          const SizedBox(height: 16),
          const Text('Ask rider for their 4-digit PIN', style: AppText.title),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(letterSpacing: 10),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              filled: true,
              fillColor: AppColors.scaffold,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Start Trip',
            icon: Icons.play_arrow_rounded,
            loading: _busy,
            onPressed: () => _startTrip(ride),
          ),
        ],
      ),
    );
  }

  Widget _ongoingCard(Ride ride) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _addressTile(Icons.location_on, AppColors.danger, 'DROP',
              ride.dropoff.address ?? 'Drop point'),
          const SizedBox(height: 12),
          Row(
            children: [
              _pill(Icons.route, Fmt.distance(ride.distanceMeters)),
              const SizedBox(width: 8),
              _pill(Icons.schedule, Fmt.duration(ride.durationSeconds)),
              const SizedBox(width: 8),
              _pill(Icons.payments_outlined, Fmt.rupees(ride.fare.total)),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Complete Trip',
            icon: Icons.flag_rounded,
            loading: _busy,
            onPressed: () => _complete(ride),
          ),
        ],
      ),
    );
  }

  Widget _riderRow(Ride ride) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary,
          child: Text(
            ride.customerName.isNotEmpty
                ? ride.customerName[0].toUpperCase()
                : 'R',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ride.customerName, style: AppText.title),
              Text(Fmt.phone(ride.customerPhone), style: AppText.bodySoft),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: () => _call(ride.customerPhone),
          icon: const Icon(Icons.call),
          style: IconButton.styleFrom(backgroundColor: AppColors.success),
        ),
      ],
    );
  }

  Widget _addressTile(
      IconData icon, Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.label),
              const SizedBox(height: 2),
              Text(address, style: AppText.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(label, style: AppText.label),
        ],
      ),
    );
  }

  // ---- Actions ------------------------------------------------------------

  Future<void> _markArrived(Ride ride) async {
    setState(() => _busy = true);
    try {
      await ref.read(rideServiceProvider).markArrived(ride.id);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTrip(Ride ride) async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      _snack('Enter the 4-digit PIN');
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(rideServiceProvider)
          .startRide(rideId: ride.id, pin: pin);
      if (!mounted) return;
      if (!ok) {
        _snack('Incorrect PIN');
        _pinController.clear();
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Ride ride) async {
    setState(() => _busy = true);
    try {
      await ref.read(rideServiceProvider).completeRide(
            ride.id,
            captainId: ref.read(authServiceProvider).uid,
          );
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Ride ride) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop('Cancelled by captain'),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(rideServiceProvider).cancelRide(
            rideId: ride.id,
            by: 'captain',
            reason: reason,
            captainId: ref.read(authServiceProvider).uid,
          );
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _snack('Cannot place call');
    }
  }

  Future<void> _navigateTo(LatLngPoint p) async {
    // Prefer the turn-by-turn navigation intent (opens the Google Maps app).
    final navUri = Uri.parse('google.navigation:q=${p.lat},${p.lng}&mode=d');
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
      return;
    }
    // Fall back to the universal Maps URL in an external app / browser.
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}',
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _snack('Cannot open maps');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
