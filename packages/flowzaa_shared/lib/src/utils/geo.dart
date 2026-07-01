import 'dart:math' as math;

import '../models/lat_lng_point.dart';

/// Geometry helpers shared by both apps.
class Geo {
  /// Great-circle distance in metres between two points.
  static double distanceMeters(LatLngPoint a, LatLngPoint b) {
    const earthRadius = 6371000.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final lat1 = _rad(a.lat);
    final lat2 = _rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  static double distanceKm(LatLngPoint a, LatLngPoint b) =>
      distanceMeters(a, b) / 1000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Bearing in degrees (0=N) from a to b — handy for rotating the car marker.
  static double bearing(LatLngPoint a, LatLngPoint b) {
    final lat1 = _rad(a.lat);
    final lat2 = _rad(b.lat);
    final dLng = _rad(b.lng - a.lng);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  /// Decode a Google encoded polyline into a list of points.
  static List<LatLngPoint> decodePolyline(String encoded) {
    final points = <LatLngPoint>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int result = 1, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 1;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLngPoint(lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }
}
