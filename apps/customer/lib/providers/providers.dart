import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- Services -----------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final rideServiceProvider = Provider<RideService>((ref) => RideService());

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

/// Geocoding + routing gateway.
///
/// Dev: free OpenStreetMap stack (no key). For production with a Google
/// billing key, swap to: `MapsService(apiKey: <key>)`.
final geoGatewayProvider = Provider<GeoGateway>((ref) => OsmGeoGateway());

// ---- Auth ---------------------------------------------------------------

/// The raw firebase auth state (null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in customer's profile row (null while loading / signed out).
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  // Rebuild whenever auth state changes so a fresh sign-in re-subscribes.
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).userProfileStream();
});

// ---- Fare config --------------------------------------------------------

/// Live fare config from `config/fares`, falling back to defaults.
final fareConfigProvider = StreamProvider<FareConfig>((ref) {
  return Refs.fareConfig.snapshots().map((doc) {
    final data = doc.data();
    if (data == null) return FareConfig.defaults;
    return FareConfig.fromMap(data);
  }).handleError((_) => FareConfig.defaults);
});

// ---- Ride history --------------------------------------------------------

/// The customer's ride history (terminal + active, newest first, limit 50).
final rideHistoryProvider = StreamProvider.autoDispose<List<Ride>>((ref) {
  final uid = ref.watch(authServiceProvider).uid;
  if (uid == null) return Stream.value(const <Ride>[]);
  return ref.watch(rideServiceProvider).historyForCustomer(uid);
});

// ---- Active ride --------------------------------------------------------

/// The customer's current active ride (searching/accepted/arrived/ongoing).
final activeRideProvider = StreamProvider.autoDispose<Ride?>((ref) {
  final uid = ref.watch(authServiceProvider).uid;
  if (uid == null) return Stream<Ride?>.value(null);
  return ref.watch(rideServiceProvider).watchActiveRideForCustomer(uid);
});
