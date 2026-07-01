import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lat_lng_point.dart';
import '../models/place.dart';
import 'geo_gateway.dart';

/// Google Maps Platform REST calls: Places autocomplete/details, Directions,
/// and reverse geocoding. The Maps *widget* lives in the apps; this is the data
/// layer, shared so fare estimates are identical in both apps.
///
/// Needs a billing-enabled Google Maps key. For key-free development use
/// [OsmGeoGateway] instead.
class MapsService implements GeoGateway {
  MapsService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _base = 'https://maps.googleapis.com/maps/api';

  /// Autocomplete predictions, biased around [near] when provided.
  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    LatLngPoint? near,
    String country = 'in',
  }) async {
    if (input.trim().isEmpty) return [];
    final params = {
      'input': input,
      'key': apiKey,
      'components': 'country:$country',
      if (near != null) 'location': '${near.lat},${near.lng}',
      if (near != null) 'radius': '30000',
    };
    final uri = Uri.parse('$_base/place/autocomplete/json')
        .replace(queryParameters: params);
    final res = await _client.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final preds = (body['predictions'] as List?) ?? [];
    return preds.map((p) {
      final sf = (p['structured_formatting'] as Map?) ?? {};
      return PlaceSuggestion(
        placeId: p['place_id'] as String? ?? '',
        primaryText: sf['main_text'] as String? ?? p['description'] as String? ?? '',
        secondaryText: sf['secondary_text'] as String? ?? '',
      );
    }).toList();
  }

  /// Resolve a place_id to coordinates + formatted address.
  @override
  Future<ResolvedPlace> placeDetails(String placeId) async {
    final uri = Uri.parse('$_base/place/details/json').replace(queryParameters: {
      'place_id': placeId,
      'key': apiKey,
      'fields': 'geometry,formatted_address',
    });
    final res = await _client.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final result = (body['result'] as Map?) ?? {};
    final loc = ((result['geometry'] as Map?)?['location'] as Map?) ?? {};
    return ResolvedPlace(
      point: LatLngPoint(
        lat: (loc['lat'] as num?)?.toDouble() ?? 0,
        lng: (loc['lng'] as num?)?.toDouble() ?? 0,
      ),
      address: result['formatted_address'] as String? ?? '',
    );
  }

  /// Reverse-geocode a coordinate to a human address (for the pickup pin).
  @override
  Future<String> reverseGeocode(LatLngPoint p) async {
    final uri = Uri.parse('$_base/geocode/json').replace(queryParameters: {
      'latlng': '${p.lat},${p.lng}',
      'key': apiKey,
    });
    final res = await _client.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    if (results.isEmpty) return '';
    return (results.first as Map)['formatted_address'] as String? ?? '';
  }

  /// Distance + duration + route polyline between two points.
  @override
  Future<RouteInfo> route(LatLngPoint origin, LatLngPoint dest) async {
    final uri = Uri.parse('$_base/directions/json').replace(queryParameters: {
      'origin': '${origin.lat},${origin.lng}',
      'destination': '${dest.lat},${dest.lng}',
      'key': apiKey,
      'mode': 'driving',
    });
    final res = await _client.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (body['routes'] as List?) ?? [];
    if (routes.isEmpty) {
      throw 'No route found (status: ${body['status']}).';
    }
    final route = routes.first as Map;
    final leg = ((route['legs'] as List).first) as Map;
    return RouteInfo(
      distanceMeters: ((leg['distance'] as Map)['value'] as num).toInt(),
      durationSeconds: ((leg['duration'] as Map)['value'] as num).toInt(),
      polyline: ((route['overview_polyline'] as Map?)?['points']) as String?,
    );
  }
}
