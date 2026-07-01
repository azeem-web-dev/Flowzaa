import 'lat_lng_point.dart';

/// A Places autocomplete suggestion.
class PlaceSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  String get fullText =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';
}

/// A resolved place with coordinates and a display address.
class ResolvedPlace {
  final LatLngPoint point;
  final String address;

  const ResolvedPlace({required this.point, required this.address});
}
