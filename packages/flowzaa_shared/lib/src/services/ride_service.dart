import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lat_lng_point.dart';
import '../models/ride.dart';
import '../models/ride_status.dart';
import '../models/vehicle_type.dart';
import 'firestore_refs.dart';

/// All ride reads/writes for both apps. The ride document is the shared state
/// machine; methods here enforce who may perform which transition (mirrored by
/// firestore.rules server-side).
class RideService {
  final _db = FirebaseFirestore.instance;

  // ---- Customer side ----------------------------------------------------

  /// Creates a searching ride and returns its id. The Cloud Function stamps the
  /// authoritative Start-PIN; we also set a local one so the UI isn't blank for
  /// the moment before the function runs (server value wins on next snapshot).
  Future<String> createRide(Ride ride) async {
    final ref = Refs.rides.doc();
    final payload = ride.toCreateMap();
    // Ensure a Start-PIN exists even before the Cloud Function stamps the
    // authoritative one (so the flow works on the free tier too).
    payload['startPin'] ??= _randomPin();
    await ref.set(payload);
    return ref.id;
  }

  static String _randomPin() =>
      (1000 + Random().nextInt(9000)).toString();

  /// Streams a single ride document.
  Stream<Ride?> watchRide(String rideId) => Refs.ride(rideId).snapshots().map(
        (doc) => doc.exists ? Ride.fromDoc(doc) : null,
      );

  /// The customer's current active ride (if any), newest first.
  Stream<Ride?> watchActiveRideForCustomer(String customerId) {
    return Refs.rides
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final ride = Ride.fromDoc(snap.docs.first);
      return ride.status.isActive ? ride : null;
    });
  }

  // ---- Captain side -----------------------------------------------------

  /// Open requests of a given vehicle type the captain can consider.
  Stream<List<Ride>> watchSearchingRides(VehicleType type) {
    return Refs.rides
        .where('status', isEqualTo: RideStatus.searching.id)
        .where('vehicleType', isEqualTo: type.id)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(Ride.fromDoc).toList());
  }

  /// The captain's current active ride (if any).
  Stream<Ride?> watchActiveRideForCaptain(String captainId) {
    return Refs.rides
        .where('captainId', isEqualTo: captainId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final ride = Ride.fromDoc(snap.docs.first);
      return ride.status.isActive ? ride : null;
    });
  }

  /// Atomically claim a still-searching ride. Returns false if another captain
  /// already took it. Also flips the captain to unavailable.
  Future<bool> acceptRide({
    required String rideId,
    required String captainId,
    required String captainName,
    required String captainPhone,
    required Map<String, dynamic> captainVehicle,
  }) async {
    final rideRef = Refs.ride(rideId);
    final captainRef = Refs.captain(captainId);
    try {
      await _db.runTransaction((txn) async {
        final snap = await txn.get(rideRef);
        final status = RideStatus.fromId(snap.data()?['status'] as String?);
        if (status != RideStatus.searching) {
          throw _RideTaken();
        }
        txn.update(rideRef, {
          'status': RideStatus.accepted.id,
          'captainId': captainId,
          'captainName': captainName,
          'captainPhone': captainPhone,
          'captainVehicle': captainVehicle,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        txn.set(captainRef, {'isAvailable': false}, SetOptions(merge: true));
      });
      return true;
    } on _RideTaken {
      return false;
    }
  }

  Future<void> markArrived(String rideId) => Refs.ride(rideId).update({
        'status': RideStatus.arrived.id,
        'arrivedAt': FieldValue.serverTimestamp(),
      });

  /// Verify the rider's PIN and start the trip. Returns false on wrong PIN.
  Future<bool> startRide({required String rideId, required String pin}) async {
    final ref = Refs.ride(rideId);
    final snap = await ref.get();
    if ((snap.data()?['startPin'] as String?) != pin) return false;
    await ref.update({
      'status': RideStatus.ongoing.id,
      'startedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Complete the trip. Pass [captainId] (the caller's uid) so the captain is
  /// marked available again — normally a Cloud Function's job, but done here
  /// too so the flow works on the free tier without deployed Functions.
  Future<void> completeRide(String rideId, {String? captainId}) async {
    await Refs.ride(rideId).update({
      'status': RideStatus.completed.id,
      'completedAt': FieldValue.serverTimestamp(),
    });
    if (captainId != null) {
      await Refs.captain(captainId)
          .set({'isAvailable': true}, SetOptions(merge: true));
    }
  }

  /// Push the captain's live position onto the ride during accepted/ongoing.
  Future<void> updateCaptainLocation(String rideId, LatLngPoint p) =>
      Refs.ride(rideId).update({'captainLocation': p.toMap()});

  /// Push the customer's live position while the captain heads to pickup, so
  /// the captain can find the rider even if they move.
  Future<void> updateCustomerLocation(String rideId, LatLngPoint p) =>
      Refs.ride(rideId).update({'customerLocation': p.toMap()});

  // ---- Either side ------------------------------------------------------

  /// Cancel the ride. A captain cancelling should pass their own uid as
  /// [captainId] to free themselves for new requests (see [completeRide]).
  Future<void> cancelRide({
    required String rideId,
    required String by, // 'customer' | 'captain'
    String? reason,
    String? captainId,
  }) async {
    await Refs.ride(rideId).update({
      'status': RideStatus.cancelled.id,
      'cancelledBy': by,
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    if (captainId != null) {
      await Refs.captain(captainId)
          .set({'isAvailable': true}, SetOptions(merge: true));
    }
  }

  Future<void> rateByCustomer(String rideId, int stars, String? review) =>
      Refs.ride(rideId).update({
        'ratingByCustomer': {'stars': stars, 'review': review},
      });

  Future<void> rateByCaptain(String rideId, int stars, String? review) =>
      Refs.ride(rideId).update({
        'ratingByCaptain': {'stars': stars, 'review': review},
      });

  /// Ride history (terminal rides), newest first.
  Stream<List<Ride>> historyForCustomer(String customerId) => Refs.rides
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Ride.fromDoc).toList());

  Stream<List<Ride>> historyForCaptain(String captainId) => Refs.rides
      .where('captainId', isEqualTo: captainId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Ride.fromDoc).toList());
}

class _RideTaken implements Exception {}
