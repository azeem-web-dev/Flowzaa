import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { customer, captain }

/// A favourite location like Home or Work, shown as a one-tap shortcut.
class SavedPlace {
  final String label;
  final String address;
  final double lat;
  final double lng;

  const SavedPlace({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() =>
      {'label': label, 'address': address, 'lat': lat, 'lng': lng};

  factory SavedPlace.fromMap(Map<String, dynamic> m) => SavedPlace(
        label: m['label'] as String? ?? '',
        address: m['address'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
      );
}

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
  final List<SavedPlace> savedPlaces;

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
    this.savedPlaces = const [],
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
        'savedPlaces': savedPlaces.map((p) => p.toMap()).toList(),
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
        savedPlaces: ((map['savedPlaces'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => SavedPlace.fromMap(m.cast<String, dynamic>()))
            .toList(),
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
