import 'dart:async';
import 'dart:math' as math;

import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/map_attribution.dart';
import '../widgets/sheet_card.dart';
import '../widgets/status_timeline.dart';
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

  /// Streams the rider's GPS onto the ride while the captain heads to pickup.
  StreamSubscription<LatLngPoint>? _myLocationSub;

  /// Previous captain point, used to derive a bearing when heading is absent.
  LatLngPoint? _prevCaptainPoint;
  double _captainBearing = 0;

  @override
  void dispose() {
    _myLocationSub?.cancel();
    super.dispose();
  }

  /// Start/stop sharing our live location depending on the ride status.
  /// Shared only while the captain is heading to us (accepted/arrived).
  void _syncLocationSharing(Ride ride) {
    final shouldShare =
        ride.status == RideStatus.accepted || ride.status == RideStatus.arrived;
    if (shouldShare && _myLocationSub == null) {
      _myLocationSub = ref
          .read(locationServiceProvider)
          .positionStream(distanceFilter: 20)
          .listen((point) {
        ref
            .read(rideServiceProvider)
            .updateCustomerLocation(widget.rideId, point)
            .catchError((_) {});
      }, onError: (_) {});
    } else if (!shouldShare && _myLocationSub != null) {
      _myLocationSub?.cancel();
      _myLocationSub = null;
    }
  }

  void _updateCaptainBearing(LatLngPoint cap) {
    final prev = _prevCaptainPoint;
    if (cap.heading != null && cap.heading != 0) {
      _captainBearing = cap.heading!;
    } else if (prev != null && (prev.lat != cap.lat || prev.lng != cap.lng)) {
      _captainBearing = Geo.bearing(prev, cap);
    }
    _prevCaptainPoint = cap;
  }

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
          angle: _captainBearing * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              ride.vehicleType.icon,
              size: 24,
              color: AppColors.ink,
            ),
          ),
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

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    await _dial(phone);
  }

  /// Emergency call — dials 112 (all-India emergency number).
  Future<void> _sos() async => _dial('112');

  Future<void> _shareTrip(Ride ride) async {
    final number = (ride.captainVehicle?['number'] as String?) ?? 'vehicle TBD';
    final text = "I'm on a Flowzaa ${ride.vehicleType.label} $number, "
        'captain ${ride.captainName ?? '—'} ${ride.captainPhone ?? '—'}, '
        'from ${ride.pickup.address ?? 'pickup'} to '
        '${ride.dropoff.address ?? 'destination'}, live PIN ${ride.id}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip details copied')),
      );
    }
  }

  /// Ask why, then cancel. Only offered before the trip starts.
  Future<void> _cancelWithReason() async {
    const reasons = [
      'Wrong pickup',
      'Captain too far',
      'Changed my mind',
      'Other',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const SheetHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Why are you cancelling?', style: AppText.h2),
            ),
            const SizedBox(height: 8),
            ...reasons.map(
              (r) => ListTile(
                leading: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkSoft),
                title: Text(r, style: AppText.title),
                onTap: () => Navigator.of(ctx).pop(r),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await ref.read(rideServiceProvider).cancelRide(
            rideId: widget.rideId,
            by: 'customer',
            reason: reason,
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
            body: Center(
              child: VehicleLoaderSmall(
                type: VehicleType.bike,
                label: 'Loading your trip…',
              ),
            ),
          );
        }

        _syncLocationSharing(ride);

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
          _updateCaptainBearing(cap);
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
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.flowzaa.customer',
                    ),
                    PolylineLayer(polylines: _polylines(ride)),
                    MarkerLayer(markers: _markers(ride)),
                    const OsmAttribution(),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _TrackingCard(
                  ride: ride,
                  onCall: () => _call(ride.captainPhone),
                  onSos: _sos,
                  onShare: () => _shareTrip(ride),
                  onCancel: ride.status == RideStatus.ongoing
                      ? null
                      : _cancelWithReason,
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
  final VoidCallback onSos;
  final VoidCallback onShare;
  final VoidCallback? onCancel;

  const _TrackingCard({
    required this.ride,
    required this.onCall,
    required this.onSos,
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
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            StatusTimeline(status: ride.status),
            const SizedBox(height: 12),
            // Status banner — cross-fades between status changes.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: Container(
                key: ValueKey(ride.status),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ride.status.customerLabel,
                  style: AppText.title.copyWith(color: AppColors.primaryDark),
                ),
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
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSos,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.sos_rounded, size: 18),
                    label: const Text('SOS'),
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
