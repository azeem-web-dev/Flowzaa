import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Conversions between the SDK-agnostic [LatLngPoint] and google_maps [LatLng].
extension LatLngPointX on LatLngPoint {
  LatLng toLatLng() => LatLng(lat, lng);
}

extension LatLngX on LatLng {
  LatLngPoint toPoint() => LatLngPoint(lat: latitude, lng: longitude);
}

/// Compute the [LatLngBounds] that contains all [points] (with a small margin).
LatLngBounds boundsFor(List<LatLng> points) {
  assert(points.isNotEmpty);
  double? minLat, maxLat, minLng, maxLng;
  for (final p in points) {
    minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
    maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
    minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
    maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
  }
  return LatLngBounds(
    southwest: LatLng(minLat!, minLng!),
    northeast: LatLng(maxLat!, maxLng!),
  );
}
