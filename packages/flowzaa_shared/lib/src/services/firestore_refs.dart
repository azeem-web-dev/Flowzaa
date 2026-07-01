import 'package:cloud_firestore/cloud_firestore.dart';

/// Central place for collection/document references so paths aren't hard-coded
/// across the codebase.
class Refs {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  static CollectionReference<Map<String, dynamic>> get captains =>
      _db.collection('captains');

  static CollectionReference<Map<String, dynamic>> get rides =>
      _db.collection('rides');

  static DocumentReference<Map<String, dynamic>> user(String uid) =>
      users.doc(uid);

  static DocumentReference<Map<String, dynamic>> captain(String uid) =>
      captains.doc(uid);

  static DocumentReference<Map<String, dynamic>> ride(String id) =>
      rides.doc(id);

  static DocumentReference<Map<String, dynamic>> get fareConfig =>
      _db.collection('config').doc('fares');
}
