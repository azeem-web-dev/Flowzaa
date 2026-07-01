import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/sheet_card.dart';
import 'searching_screen.dart';

class RideOptionsScreen extends ConsumerStatefulWidget {
  final LatLngPoint pickup;
  final LatLngPoint dropoff;
  final RouteInfo route;

  const RideOptionsScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.route,
  });

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  GoogleMapController? _map;
  VehicleType _selected = VehicleType.bike;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _booking = false;

  // A tiny ETA heuristic per vehicle type (minutes until pickup).
  static const _etas = {
    VehicleType.bike: 3,
    VehicleType.auto: 4,
    VehicleType.car: 6,
    VehicleType.parcel: 5,
  };

  Set<Polyline> _polylines() {
    final encoded = widget.route.polyline;
    if (encoded == null || encoded.isEmpty) return {};
    final pts = Geo.decodePolyline(encoded).map((p) => p.toLatLng()).toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: AppColors.primary,
        width: 5,
      ),
    };
  }

  Set<Marker> _markers() => {
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
        Marker(
          markerId: const MarkerId('drop'),
          position: widget.dropoff.toLatLng(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Drop'),
        ),
      };

  void _fitBounds() {
    final map = _map;
    if (map == null) return;
    final bounds = boundsFor([
      widget.pickup.toLatLng(),
      widget.dropoff.toLatLng(),
    ]);
    map.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _book(FareConfig config) async {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still loading your profile…')),
      );
      return;
    }
    setState(() => _booking = true);

    final fare = const FareCalculator().compute(
      config: config,
      type: _selected,
      distanceMeters: widget.route.distanceMeters.toDouble(),
      durationSeconds: widget.route.durationSeconds.toDouble(),
    );

    final ride = Ride(
      id: '',
      customerId: profile.uid,
      customerName: profile.name,
      customerPhone: profile.phone,
      status: RideStatus.searching,
      vehicleType: _selected,
      pickup: widget.pickup,
      dropoff: widget.dropoff,
      distanceMeters: widget.route.distanceMeters,
      durationSeconds: widget.route.durationSeconds,
      routePolyline: widget.route.polyline,
      fare: fare,
      paymentMethod: _payment,
    );

    try {
      final id = await ref.read(rideServiceProvider).createRide(ride);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SearchingScreen(rideId: id),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book ride: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(fareConfigProvider);
    final config = configAsync.value ?? FareConfig.defaults;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.pickup.toLatLng(),
                zoom: 13,
              ),
              markers: _markers(),
              polylines: _polylines(),
              zoomControlsEnabled: false,
              onMapCreated: (c) {
                _map = c;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _fitBounds());
              },
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SheetCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  Row(
                    children: [
                      const Icon(Icons.route_rounded,
                          size: 18, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                        '${Fmt.distance(widget.route.distanceMeters)} · ${Fmt.duration(widget.route.durationSeconds)}',
                        style: AppText.bodySoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...VehicleType.values.map((type) {
                    final fare = const FareCalculator().compute(
                      config: config,
                      type: type,
                      distanceMeters: widget.route.distanceMeters.toDouble(),
                      durationSeconds:
                          widget.route.durationSeconds.toDouble(),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VehicleTypeTile(
                        type: type,
                        fare: fare.total,
                        etaMinutes: _etas[type] ?? 4,
                        selected: _selected == type,
                        onTap: () => setState(() => _selected = type),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  _PaymentToggle(
                    method: _payment,
                    onChanged: (m) => setState(() => _payment = m),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Book ${_selected.label}',
                    loading: _booking,
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () => _book(config),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onChanged;

  const _PaymentToggle({required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(PaymentMethod m, IconData icon, String label) {
      final selected = method == m;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(m),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.inkSoft),
                const SizedBox(width: 8),
                Text(label, style: AppText.title),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(PaymentMethod.cash, Icons.payments_rounded, 'Cash'),
        const SizedBox(width: 10),
        option(PaymentMethod.upi, Icons.qr_code_rounded, 'UPI'),
      ],
    );
  }
}
