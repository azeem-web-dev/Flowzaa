import 'package:geolocator/geolocator.dart';

import '../models/lat_lng_point.dart';

/// Thin wrapper over geolocator: permissions, one-shot position, and a live
/// stream used for the captain's location updates and the customer's blue dot.
class LocationService {
  /// Ensures location services + permission are granted. Throws with a
  /// human-readable message if the user refuses.
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are turned off. Please enable GPS.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw 'Location permission denied.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Enable it in Settings.';
    }
  }

  Future<LatLngPoint> currentPosition() async {
    await ensurePermission();
    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLngPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      heading: pos.heading,
    );
  }

  /// A stream of positions, emitting when the device moves [distanceFilter] m.
  Stream<LatLngPoint> positionStream({int distanceFilter = 15}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).map((pos) => LatLngPoint(
          lat: pos.latitude,
          lng: pos.longitude,
          heading: pos.heading,
        ));
  }
}
