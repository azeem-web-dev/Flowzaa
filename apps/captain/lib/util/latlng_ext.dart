import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Conversions between the shared [LatLngPoint] and google_maps [LatLng].
extension LatLngPointX on LatLngPoint {
  LatLng toLatLng() => LatLng(lat, lng);
}

extension LatLngX on LatLng {
  LatLngPoint toPoint() => LatLngPoint(lat: latitude, lng: longitude);
}
