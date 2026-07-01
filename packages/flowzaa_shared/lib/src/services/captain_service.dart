import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/captain.dart';
import '../models/lat_lng_point.dart';
import '../models/vehicle_type.dart';
import 'firestore_refs.dart';

/// Captain profile, availability toggle and live-location push.
class CaptainService {
  Stream<Captain?> watch(String uid) => Refs.captain(uid).snapshots().map(
        (doc) => doc.exists ? Captain.fromDoc(doc) : null,
      );

  Future<Captain?> fetch(String uid) async {
    final doc = await Refs.captain(uid).get();
    return doc.exists ? Captain.fromDoc(doc) : null;
  }

  /// Create the captain row if missing (called right after OTP sign-in).
  Future<Captain> ensureProfile({
    required String uid,
    required String phone,
    String? fcmToken,
  }) async {
    final ref = Refs.captain(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final captain = Captain(uid: uid, name: '', phone: phone, fcmToken: fcmToken);
      await ref.set(captain.toMap()..['createdAt'] = FieldValue.serverTimestamp());
      return captain;
    }
    if (fcmToken != null) {
      await ref.set({'fcmToken': fcmToken}, SetOptions(merge: true));
    }
    return Captain.fromDoc(await ref.get());
  }

  /// Save the vehicle/profile details from onboarding.
  Future<void> saveProfile({
    required String uid,
    required String name,
    required VehicleType vehicleType,
    required String vehicleNumber,
    required String vehicleModel,
    required String licenseNumber,
    String? upiId,
  }) =>
      Refs.captain(uid).set({
        'name': name,
        'vehicleType': vehicleType.id,
        'vehicleNumber': vehicleNumber,
        'vehicleModel': vehicleModel,
        'licenseNumber': licenseNumber,
        'upiId': upiId,
        // Auto-approve in this build; wire real verification later.
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> setOnline(String uid, bool online) => Refs.captain(uid).set({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Push the captain's current location (and mark them seen).
  Future<void> updateLocation(String uid, LatLngPoint p) =>
      Refs.captain(uid).set({
        'location': p.toMap(),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
