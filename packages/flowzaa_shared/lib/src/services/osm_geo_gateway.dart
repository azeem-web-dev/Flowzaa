import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lat_lng_point.dart';
import '../models/place.dart';
import 'geo_gateway.dart';

/// Free, key-free geocoding + routing for development, backed by:
///  - OpenStreetMap **Nominatim** for search & reverse geocoding
///  - **OSRM** (public demo server) for driving routes
///
/// No API key or billing required. These are shared community servers with
/// light usage policies — perfect for dev/demo, not for heavy production
/// traffic (switch to [MapsService] with a Google key for that).
class OsmGeoGateway implements GeoGateway {
  OsmGeoGateway({http.Client? client, this.userAgent = 'Flowzaa/0.1 (dev)'})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Nominatim's usage policy requires a descriptive User-Agent.
  final String userAgent;

  static const _nominatim = 'https://nominatim.openstreetmap.org';
  static const _osrm = 'https://router.project-osrm.org';

  Map<String, String> get _headers => {'User-Agent': userAgent};

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    LatLngPoint? near,
    String country = 'in',
  }) async {
    if (input.trim().isEmpty) return [];
    final uri = Uri.parse('$_nominatim/search').replace(queryParameters: {
      'q': input,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
      if (country.isNotEmpty) 'countrycodes': country,
    });
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];
    final list = (jsonDecode(res.body) as List?) ?? [];
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      final lat = double.tryParse('${m['lat']}') ?? 0;
      final lon = double.tryParse('${m['lon']}') ?? 0;
      final display = m['display_name'] as String? ?? '';
      final parts = display.split(',');
      final primary = parts.isNotEmpty ? parts.first.trim() : display;
      final secondary =
          parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
      // Encode coords + address into the placeId so placeDetails needs no
      // extra network call (keeps the GeoGateway contract with one round-trip).
      final placeId = '$lat|$lon|$display';
      return PlaceSuggestion(
        placeId: placeId,
        primaryText: primary,
        secondaryText: secondary,
      );
    }).toList();
  }

  @override
  Future<ResolvedPlace> placeDetails(String placeId) async {
    // placeId is "lat|lon|address" (see autocomplete).
    final parts = placeId.split('|');
    final lat = double.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final lon = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final address = parts.length > 2 ? parts.sublist(2).join('|') : '';
    return ResolvedPlace(
      point: LatLngPoint(lat: lat, lng: lon, address: address),
      address: address,
    );
  }

  @override
  Future<String> reverseGeocode(LatLngPoint p) async {
    final uri = Uri.parse('$_nominatim/reverse').replace(queryParameters: {
      'lat': '${p.lat}',
      'lon': '${p.lng}',
      'format': 'jsonv2',
    });
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return '';
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return m['display_name'] as String? ?? '';
  }

  @override
  Future<RouteInfo> route(LatLngPoint origin, LatLngPoint dest) async {
    // OSRM expects lon,lat order.
    final coords =
        '${origin.lng},${origin.lat};${dest.lng},${dest.lat}';
    final uri = Uri.parse('$_osrm/route/v1/driving/$coords').replace(
      queryParameters: {'overview': 'full', 'geometries': 'polyline'},
    );
    final res = await _client.get(uri, headers: _headers);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (body['routes'] as List?) ?? [];
    if (routes.isEmpty) {
      throw 'No route found (OSRM status: ${body['code']}).';
    }
    final r = routes.first as Map<String, dynamic>;
    return RouteInfo(
      distanceMeters: (r['distance'] as num?)?.round() ?? 0,
      durationSeconds: (r['duration'] as num?)?.round() ?? 0,
      polyline: r['geometry'] as String?,
    );
  }
}
