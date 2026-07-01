import 'package:cloud_firestore/cloud_firestore.dart';

import 'lat_lng_point.dart';
import 'vehicle_type.dart';

enum CaptainStatus { pendingVerification, approved, blocked }

CaptainStatus _statusFromId(String? id) {
  switch (id) {
    case 'approved':
      return CaptainStatus.approved;
    case 'blocked':
      return CaptainStatus.blocked;
    default:
      return CaptainStatus.pendingVerification;
  }
}

String _statusId(CaptainStatus s) {
  switch (s) {
    case CaptainStatus.approved:
      return 'approved';
    case CaptainStatus.blocked:
      return 'blocked';
    case CaptainStatus.pendingVerification:
      return 'pending_verification';
  }
}

/// A captain (rider) — profile, vehicle, live availability & location.
class Captain {
  final String uid;
  final String name;
  final String phone;
  final String? photoUrl;
  final VehicleType vehicleType;
  final String vehicleNumber;
  final String vehicleModel;
  final String licenseNumber;

  /// The captain's OWN UPI id — Flowzaa shows this as a QR to the rider.
  /// 0% commission: money moves rider → captain directly.
  final String? upiId;

  final CaptainStatus status;
  final bool isOnline;
  final bool isAvailable;
  final LatLngPoint? location;
  final double rating;
  final int ratingCount;
  final int totalRides;
  final String? fcmToken;

  const Captain({
    required this.uid,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.vehicleType = VehicleType.bike,
    this.vehicleNumber = '',
    this.vehicleModel = '',
    this.licenseNumber = '',
    this.upiId,
    this.status = CaptainStatus.pendingVerification,
    this.isOnline = false,
    this.isAvailable = true,
    this.location,
    this.rating = 5.0,
    this.ratingCount = 0,
    this.totalRides = 0,
    this.fcmToken,
  });

  bool get isProfileComplete =>
      name.isNotEmpty &&
      vehicleNumber.isNotEmpty &&
      licenseNumber.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'photoUrl': photoUrl,
        'vehicleType': vehicleType.id,
        'vehicleNumber': vehicleNumber,
        'vehicleModel': vehicleModel,
        'licenseNumber': licenseNumber,
        'upiId': upiId,
        'status': _statusId(status),
        'isOnline': isOnline,
        'isAvailable': isAvailable,
        'location': location?.toMap(),
        'rating': rating,
        'ratingCount': ratingCount,
        'totalRides': totalRides,
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Captain.fromMap(Map<String, dynamic> map) => Captain(
        uid: map['uid'] as String? ?? '',
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        photoUrl: map['photoUrl'] as String?,
        vehicleType: VehicleType.fromId(map['vehicleType'] as String?),
        vehicleNumber: map['vehicleNumber'] as String? ?? '',
        vehicleModel: map['vehicleModel'] as String? ?? '',
        licenseNumber: map['licenseNumber'] as String? ?? '',
        upiId: map['upiId'] as String?,
        status: _statusFromId(map['status'] as String?),
        isOnline: map['isOnline'] as bool? ?? false,
        isAvailable: map['isAvailable'] as bool? ?? true,
        location: map['location'] == null
            ? null
            : LatLngPoint.fromMap(
                (map['location'] as Map).cast<String, dynamic>()),
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
        totalRides: (map['totalRides'] as num?)?.toInt() ?? 0,
        fcmToken: map['fcmToken'] as String?,
      );

  factory Captain.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Captain.fromMap({...?doc.data(), 'uid': doc.id});

  Captain copyWith({
    String? name,
    String? photoUrl,
    VehicleType? vehicleType,
    String? vehicleNumber,
    String? vehicleModel,
    String? licenseNumber,
    String? upiId,
    CaptainStatus? status,
    bool? isOnline,
    bool? isAvailable,
    LatLngPoint? location,
    String? fcmToken,
  }) =>
      Captain(
        uid: uid,
        name: name ?? this.name,
        phone: phone,
        photoUrl: photoUrl ?? this.photoUrl,
        vehicleType: vehicleType ?? this.vehicleType,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        vehicleModel: vehicleModel ?? this.vehicleModel,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        upiId: upiId ?? this.upiId,
        status: status ?? this.status,
        isOnline: isOnline ?? this.isOnline,
        isAvailable: isAvailable ?? this.isAvailable,
        location: location ?? this.location,
        rating: rating,
        ratingCount: ratingCount,
        totalRides: totalRides,
        fcmToken: fcmToken ?? this.fcmToken,
      );
}
