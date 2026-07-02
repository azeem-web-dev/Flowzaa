import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../util/latlng_ext.dart';
import '../widgets/map_attribution.dart';
import '../widgets/sheet_card.dart';
import 'searching_screen.dart';

class RideOptionsScreen extends ConsumerStatefulWidget {
  final LatLngPoint pickup;
  final LatLngPoint dropoff;
  final RouteInfo route;

  /// Ride type preselected from the home shortcut chips.
  final VehicleType? initialType;

  const RideOptionsScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.route,
    this.initialType,
  });

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  final MapController _map = MapController();
  late VehicleType _selected = widget.initialType ?? VehicleType.bike;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _booking = false;

  // Parcel details (required when booking a parcel).
  final _receiverNameCtrl = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _parcelNoteCtrl = TextEditingController();

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _parcelNoteCtrl.dispose();
    super.dispose();
  }

  // A tiny ETA heuristic per vehicle type (minutes until pickup).
  static const _etas = {
    VehicleType.bike: 3,
    VehicleType.auto: 4,
    VehicleType.car: 6,
    VehicleType.parcel: 5,
  };

  List<Polyline> _polylines() {
    final encoded = widget.route.polyline;
    if (encoded == null || encoded.isEmpty) return [];
    return [
      Polyline(
        points: decodeToLatLng(encoded),
        color: AppColors.primary,
        strokeWidth: 5,
      ),
    ];
  }

  List<Marker> _markers() => [
        Marker(
          point: widget.pickup.toLatLng(),
          width: 44,
          height: 44,
          child: const Icon(Icons.trip_origin, color: AppColors.primary),
        ),
        Marker(
          point: widget.dropoff.toLatLng(),
          width: 44,
          height: 44,
          child: const Icon(Icons.location_on, color: AppColors.danger),
        ),
      ];

  void _fitBounds() {
    _map.fitCamera(
      CameraFit.bounds(
        bounds: boundsFor([
          widget.pickup.toLatLng(),
          widget.dropoff.toLatLng(),
        ]),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  /// Validated parcel payload, or null (with a snackbar) if incomplete.
  Map<String, dynamic>? _parcelInfoOrWarn() {
    final name = _receiverNameCtrl.text.trim();
    final phone = _receiverPhoneCtrl.text.trim();
    final note = _parcelNoteCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add the receiver's name and phone number."),
        ),
      );
      return null;
    }
    return {
      'receiverName': name,
      'receiverPhone': phone,
      if (note.isNotEmpty) 'note': note,
    };
  }

  Future<void> _book(FareConfig config) async {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still loading your profile…')),
      );
      return;
    }
    Map<String, dynamic>? parcelInfo;
    if (_selected == VehicleType.parcel) {
      parcelInfo = _parcelInfoOrWarn();
      if (parcelInfo == null) return;
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
      parcelInfo: parcelInfo,
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
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: widget.pickup.toLatLng(),
                initialZoom: 13,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
                onMapReady: () => WidgetsBinding.instance
                    .addPostFrameCallback((_) => _fitBounds()),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.flowzaa.customer',
                ),
                PolylineLayer(polylines: _polylines()),
                MarkerLayer(markers: _markers()),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                child: SingleChildScrollView(
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
                      for (final (i, type) in VehicleType.values.indexed)
                        Builder(builder: (context) {
                          final fare = const FareCalculator().compute(
                            config: config,
                            type: type,
                            distanceMeters:
                                widget.route.distanceMeters.toDouble(),
                            durationSeconds:
                                widget.route.durationSeconds.toDouble(),
                          );
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 50 * i),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: VehicleTypeTile(
                                type: type,
                                fare: fare.total,
                                etaMinutes: _etas[type] ?? 4,
                                selected: _selected == type,
                                onTap: () => setState(() => _selected = type),
                              ),
                            ),
                          );
                        }),
                      if (_selected == VehicleType.parcel) ...[
                        const SizedBox(height: 4),
                        const Text('Parcel details', style: AppText.title),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _receiverNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Receiver name',
                            isDense: true,
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _receiverPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Receiver phone',
                            isDense: true,
                            prefixIcon: Icon(Icons.call_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _parcelNoteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Note for captain (optional)',
                            isDense: true,
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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
              color:
                  selected ? AppColors.primary.withOpacity(0.08) : Colors.white,
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
