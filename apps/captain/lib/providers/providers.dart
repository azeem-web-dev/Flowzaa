import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- Services -------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final captainServiceProvider =
    Provider<CaptainService>((ref) => CaptainService());
final rideServiceProvider = Provider<RideService>((ref) => RideService());
final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

// ---- Auth state -----------------------------------------------------------

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in captain's uid (null when signed out).
final uidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

// ---- Captain profile ------------------------------------------------------

final captainProvider = StreamProvider.autoDispose<Captain?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(captainServiceProvider).watch(uid);
});

// ---- Active ride ----------------------------------------------------------

final activeRideProvider = StreamProvider.autoDispose<Ride?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(rideServiceProvider).watchActiveRideForCaptain(uid);
});

// ---- Ride history / earnings ------------------------------------------------

/// The captain's recent rides (newest first) — drives the earnings summary
/// on home and the full earnings screen.
final rideHistoryProvider = StreamProvider.autoDispose<List<Ride>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(rideServiceProvider).historyForCaptain(uid);
});
