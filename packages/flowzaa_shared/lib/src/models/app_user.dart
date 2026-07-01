import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, captain }

/// A customer profile (also the identity row for anyone in `users`).
class AppUser {
  final String uid;
  final UserRole role;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String? fcmToken;
  final double rating;
  final int ratingCount;

  const AppUser({
    required this.uid,
    this.role = UserRole.customer,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.fcmToken,
    this.rating = 5.0,
    this.ratingCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role.name,
        'name': name,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'fcmToken': fcmToken,
        'rating': rating,
        'ratingCount': ratingCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String? ?? '',
        role: (map['role'] == 'captain') ? UserRole.captain : UserRole.customer,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String?,
        photoUrl: map['photoUrl'] as String?,
        fcmToken: map['fcmToken'] as String?,
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      );

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap({...?doc.data(), 'uid': doc.id});

  AppUser copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? fcmToken,
  }) =>
      AppUser(
        uid: uid,
        role: role,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        fcmToken: fcmToken ?? this.fcmToken,
        rating: rating,
        ratingCount: ratingCount,
      );
}
