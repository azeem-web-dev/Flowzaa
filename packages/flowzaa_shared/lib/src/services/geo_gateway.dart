import '../models/lat_lng_point.dart';
import '../models/place.dart';

/// Distance + duration + route geometry between two points.
class RouteInfo {
  final int distanceMeters;
  final int durationSeconds;
  final String? polyline; // encoded polyline (precision 1e5)

  const RouteInfo({
    required this.distanceMeters,
    required this.durationSeconds,
    this.polyline,
  });
}

/// A provider-agnostic geocoding + routing gateway.
///
/// Two implementations ship with Flowzaa:
///  - [OsmGeoGateway]  — free, no API key (OpenStreetMap Nominatim + OSRM).
///    Used for development.
///  - [MapsService]    — Google Maps Platform (needs a billing-enabled key).
///    Switch to this in production by swapping the provider.
abstract class GeoGateway {
  /// Address/place suggestions for [input].
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    LatLngPoint? near,
    String country = 'in',
  });

  /// Resolve a suggestion (its [PlaceSuggestion.placeId]) to coords + address.
  Future<ResolvedPlace> placeDetails(String placeId);

  /// Human-readable address for a coordinate.
  Future<String> reverseGeocode(LatLngPoint p);

  /// Driving route (distance, ETA, polyline) between two points.
  Future<RouteInfo> route(LatLngPoint origin, LatLngPoint dest);
}
