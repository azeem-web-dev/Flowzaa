import 'package:cloud_firestore/cloud_firestore.dart';

/// A plain geographic point + optional heading/address, decoupled from any
/// map SDK type so the shared package doesn't depend on google_maps_flutter.
class LatLngPoint {
  final double lat;
  final double lng;
  final double? heading;
  final String? address;

  const LatLngPoint({
    required this.lat,
    required this.lng,
    this.heading,
    this.address,
  });

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        if (heading != null) 'heading': heading,
        if (address != null) 'address': address,
      };

  factory LatLngPoint.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return LatLngPoint(
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      heading: (map['heading'] as num?)?.toDouble(),
      address: map['address'] as String?,
    );
  }

  GeoPoint toGeoPoint() => GeoPoint(lat, lng);

  LatLngPoint copyWith({
    double? lat,
    double? lng,
    double? heading,
    String? address,
  }) =>
      LatLngPoint(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        heading: heading ?? this.heading,
        address: address ?? this.address,
      );

  @override
  String toString() => 'LatLngPoint($lat, $lng)';
}
