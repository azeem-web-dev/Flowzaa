import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/sheet_card.dart';
import 'ride_complete_screen.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const TrackingScreen({super.key, required this.rideId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _map = MapController();
  bool _navigatedComplete = false;

  List<Marker> _markers(Ride ride) {
    final markers = <Marker>[
      Marker(
        point: ride.pickup.toLatLng(),
        width: 44,
        height: 44,
        child: const Icon(Icons.trip_origin, color: AppColors.primary),
      ),
      Marker(
        point: ride.dropoff.toLatLng(),
        width: 44,
        height: 44,
        child: const Icon(Icons.location_on, color: AppColors.danger),
      ),
    ];
    final cap = ride.captainLocation;
    if (cap != null) {
      markers.add(Marker(
        point: cap.toLatLng(),
        width: 44,
        height: 44,
        child: Transform.rotate(
          angle: (cap.heading ?? 0) * 3.1415926535 / 180,
          child: const Icon(Icons.two_wheeler, color: AppColors.ink),
        ),
      ));
    }
    return markers;
  }

  List<Polyline> _polylines(Ride ride) {
    final encoded = ride.routePolyline;
    if (encoded == null || encoded.isEmpty) return [];
    return [
      Polyline(
        points: decodeToLatLng(encoded),
        color: AppColors.primary,
        strokeWidth: 5,
      ),
    ];
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareTrip(Ride ride) async {
    // Keep simple: copy trip info to the clipboard.
    final text =
        'Tracking my Flowzaa ride ${ride.id}.\nCaptain: ${ride.captainName ?? '—'} '
        '(${ride.captainPhone ?? '—'})\nStatus: ${ride.status.customerLabel}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip details copied to clipboard')),
      );
    }
  }

  Future<void> _cancel() async {
    try {
      await ref.read(rideServiceProvider).cancelRide(
            rideId: widget.rideId,
            by: 'customer',
          );
    } catch (_) {}
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final rideStream = ref.watch(rideServiceProvider);
    return StreamBuilder<Ride?>(
      stream: rideStream.watchRide(widget.rideId),
      builder: (context, snap) {
        final ride = snap.data;
        if (ride == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (ride.status == RideStatus.completed && !_navigatedComplete) {
          _navigatedComplete = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => RideCompleteScreen(rideId: widget.rideId),
            ));
          });
        }

        if (ride.status == RideStatus.cancelled ||
            ride.status == RideStatus.expired) {
          return _TerminalNotice(status: ride.status);
        }

        // Keep the captain in view when their location updates.
        final cap = ride.captainLocation;
        if (cap != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _map.move(cap.toLatLng(), _map.camera.zoom);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: (cap ?? ride.pickup).toLatLng(),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.flowzaa.customer',
                    ),
                    PolylineLayer(polylines: _polylines(ride)),
                    MarkerLayer(markers: _markers(ride)),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _TrackingCard(
                  ride: ride,
                  onCall: () => _call(ride.captainPhone),
                  onShare: () => _shareTrip(ride),
                  onCancel: ride.status == RideStatus.ongoing ? null : _cancel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback onCall;
  final VoidCallback onShare;
  final VoidCallback? onCancel;

  const _TrackingCard({
    required this.ride,
    required this.onCall,
    required this.onShare,
    required this.onCancel,
  });

  bool get _showPin =>
      ride.status == RideStatus.accepted || ride.status == RideStatus.arrived;

  @override
  Widget build(BuildContext context) {
    final vehicle = ride.captainVehicle ?? const {};
    final number = vehicle['number'] as String?;
    final model = vehicle['model'] as String?;

    return SheetCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          // Status banner.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ride.status.customerLabel,
              style: AppText.title.copyWith(color: AppColors.primaryDark),
            ),
          ),
          if (_showPin) ...[
            const SizedBox(height: 14),
            _PinDisplay(pin: ride.startPin),
          ],
          const SizedBox(height: 14),
          // Captain info.
          if (ride.captainId != null)
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.scaffold,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride.captainName ?? 'Captain',
                          style: AppText.title),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (model != null && model.isNotEmpty) model,
                          if (number != null && number.isNotEmpty) number,
                        ].join(' · '),
                        style: AppText.bodySoft,
                      ),
                      const SizedBox(height: 2),
                      const RatingStars(value: 5, size: 16),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share trip'),
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PinDisplay extends StatelessWidget {
  final String? pin;
  const _PinDisplay({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share this Start-PIN with your captain',
              style: AppText.label.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            pin ?? '– – – –',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalNotice extends StatelessWidget {
  final RideStatus status;
  const _TerminalNotice({required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(status.customerLabel, style: AppText.h1),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Back to home',
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
