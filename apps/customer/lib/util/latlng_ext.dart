import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

/// Conversions between the SDK-agnostic [LatLngPoint] and flutter_map's [LatLng].
extension LatLngPointX on LatLngPoint {
  LatLng toLatLng() => LatLng(lat, lng);
}

extension LatLngX on LatLng {
  LatLngPoint toPoint() => LatLngPoint(lat: latitude, lng: longitude);
}

/// Decode a Google-encoded polyline directly into flutter_map [LatLng] points.
List<LatLng> decodeToLatLng(String encoded) =>
    Geo.decodePolyline(encoded).map((p) => LatLng(p.lat, p.lng)).toList();

/// Compute the [LatLngBounds] that contains all [points].
LatLngBounds boundsFor(List<LatLng> points) =>
    LatLngBounds.fromPoints(points);
