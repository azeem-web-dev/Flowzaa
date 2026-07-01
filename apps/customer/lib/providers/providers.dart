import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Google Maps / Places API key, read from the bundled .env asset.
final mapsApiKeyProvider = Provider<String>((ref) {
  return dotenv.maybeGet('MAPS_API_KEY') ?? 'YOUR_MAPS_API_KEY';
});

// ---- Services -----------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final rideServiceProvider = Provider<RideService>((ref) => RideService());

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

final mapsServiceProvider = Provider<MapsService>((ref) {
  return MapsService(apiKey: ref.watch(mapsApiKeyProvider));
});

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

// ---- Active ride --------------------------------------------------------

/// The customer's current active ride (searching/accepted/arrived/ongoing).
final activeRideProvider = StreamProvider.autoDispose<Ride?>((ref) {
  final uid = ref.watch(authServiceProvider).uid;
  if (uid == null) return Stream<Ride?>.value(null);
  return ref.watch(rideServiceProvider).watchActiveRideForCustomer(uid);
});
