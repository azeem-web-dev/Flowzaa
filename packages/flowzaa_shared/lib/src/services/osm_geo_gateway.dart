import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lat_lng_point.dart';
import '../models/place.dart';
import 'geo_gateway.dart';

/// Free, key-free geocoding + routing for development, backed by:
///  - **Photon** (komoot) for typo-tolerant, as-you-type place search
///  - OpenStreetMap **Nominatim** for reverse geocoding (and search fallback)
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

  static const _photon = 'https://photon.komoot.io';
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
    // Photon first: purpose-built for autocomplete (typo-tolerant, ranked,
    // location-biased). Fall back to Nominatim if it's unavailable.
    try {
      final results = await _photonSearch(input, near: near);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // fall through to Nominatim
    }
    return _nominatimSearch(input, country: country);
  }

  Future<List<PlaceSuggestion>> _photonSearch(
    String input, {
    LatLngPoint? near,
  }) async {
    final uri = Uri.parse('$_photon/api/').replace(queryParameters: {
      'q': input,
      'limit': '8',
      'lang': 'en',
      // Bias results towards the user's position so "market" finds the one
      // nearby, not one 800 km away.
      if (near != null) 'lat': '${near.lat}',
      if (near != null) 'lon': '${near.lng}',
    });
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? [];
    final seen = <String>{};
    final out = <PlaceSuggestion>[];
    for (final raw in features) {
      final f = (raw as Map).cast<String, dynamic>();
      final props = ((f['properties'] as Map?) ?? {}).cast<String, dynamic>();
      final coords =
          (((f['geometry'] as Map?) ?? {})['coordinates'] as List?) ?? [0, 0];
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final name = props['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final secondary = [
        props['street'],
        props['district'],
        props['city'],
        props['state'],
      ].whereType<String>().where((s) => s.isNotEmpty && s != name).join(', ');
      final key = '$name|$secondary';
      if (!seen.add(key)) continue; // dedupe near-identical entries
      final address = secondary.isEmpty ? name : '$name, $secondary';
      out.add(PlaceSuggestion(
        // placeId encodes coords + address: placeDetails stays offline.
        placeId: '$lat|$lon|$address',
        primaryText: name,
        secondaryText: secondary,
      ));
    }
    return out;
  }

  Future<List<PlaceSuggestion>> _nominatimSearch(
    String input, {
    String country = 'in',
  }) async {
    final uri = Uri.parse('$_nominatim/search').replace(queryParameters: {
      'q': input,
      'format': 'jsonv2',
      'addressdetails': '1',
      'dedupe': '1',
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
