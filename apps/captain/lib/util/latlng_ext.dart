import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

/// Conversions between the shared [LatLngPoint] and latlong2's [LatLng].
extension LatLngPointX on LatLngPoint {
  LatLng get toLatLng => LatLng(lat, lng);
}

extension LatLngX on LatLng {
  LatLngPoint get toPoint => LatLngPoint(lat: latitude, lng: longitude);
}

/// Decodes an encoded polyline into a list of latlong2 [LatLng] points.
List<LatLng> decodeToLatLng(String encoded) =>
    Geo.decodePolyline(encoded).map((p) => LatLng(p.lat, p.lng)).toList();

/// Bounds enclosing all [points] (empty-safe: caller must ensure non-empty).
LatLngBounds boundsOf(List<LatLng> points) => LatLngBounds.fromPoints(points);
