import 'package:cloud_firestore/cloud_firestore.dart';

import 'fare.dart';
import 'lat_lng_point.dart';
import 'ride_status.dart';
import 'vehicle_type.dart';

enum PaymentMethod {
  cash,
  upi;

  String get id => name;
  String get label => this == PaymentMethod.upi ? 'UPI QR' : 'Cash';

  static PaymentMethod fromId(String? id) =>
      id == 'upi' ? PaymentMethod.upi : PaymentMethod.cash;
}

/// A rider's rating of the other party.
class RideRating {
  final int stars;
  final String? review;
  const RideRating({required this.stars, this.review});

  Map<String, dynamic> toMap() => {'stars': stars, 'review': review};
  factory RideRating.fromMap(Map<String, dynamic> m) =>
      RideRating(stars: (m['stars'] as num?)?.toInt() ?? 0, review: m['review'] as String?);
}

/// The central ride document — a shared state machine both apps subscribe to.
class Ride {
  final String id;

  // Customer
  final String customerId;
  final String customerName;
  final String customerPhone;

  // Captain (null until accepted)
  final String? captainId;
  final String? captainName;
  final String? captainPhone;
  final Map<String, dynamic>? captainVehicle; // {type, number, model}

  final RideStatus status;
  final VehicleType vehicleType;

  final LatLngPoint pickup;
  final LatLngPoint dropoff;

  final int distanceMeters;
  final int durationSeconds;
  final String? routePolyline;

  final Fare fare;
  final String? startPin;
  final PaymentMethod paymentMethod;

  /// Live captain position, updated during accepted/ongoing.
  final LatLngPoint? captainLocation;

  /// Live customer position, streamed while the captain heads to pickup so
  /// the captain can find the rider even if they move.
  final LatLngPoint? customerLocation;

  /// For parcel rides: {receiverName, receiverPhone, note}.
  final Map<String, dynamic>? parcelInfo;

  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy; // customer | captain | system
  final String? cancelReason;

  final RideRating? ratingByCustomer;
  final RideRating? ratingByCaptain;

  const Ride({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.captainId,
    this.captainName,
    this.captainPhone,
    this.captainVehicle,
    this.status = RideStatus.searching,
    required this.vehicleType,
    required this.pickup,
    required this.dropoff,
    required this.distanceMeters,
    required this.durationSeconds,
    this.routePolyline,
    required this.fare,
    this.startPin,
    this.paymentMethod = PaymentMethod.cash,
    this.captainLocation,
    this.customerLocation,
    this.parcelInfo,
    this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.ratingByCustomer,
    this.ratingByCaptain,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();

  /// Payload for creating a new ride (customer side). Server stamps startPin.
  Map<String, dynamic> toCreateMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'captainId': null,
        'captainName': null,
        'captainPhone': null,
        'captainVehicle': null,
        'status': RideStatus.searching.id,
        'vehicleType': vehicleType.id,
        'pickup': pickup.toMap(),
        'dropoff': dropoff.toMap(),
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'routePolyline': routePolyline,
        'fare': fare.toMap(),
        'startPin': startPin,
        'paymentMethod': paymentMethod.id,
        if (parcelInfo != null) 'parcelInfo': parcelInfo,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Ride.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Ride(
      id: doc.id,
      customerId: m['customerId'] as String? ?? '',
      customerName: m['customerName'] as String? ?? '',
      customerPhone: m['customerPhone'] as String? ?? '',
      captainId: m['captainId'] as String?,
      captainName: m['captainName'] as String?,
      captainPhone: m['captainPhone'] as String?,
      captainVehicle: (m['captainVehicle'] as Map?)?.cast<String, dynamic>(),
      status: RideStatus.fromId(m['status'] as String?),
      vehicleType: VehicleType.fromId(m['vehicleType'] as String?),
      pickup: LatLngPoint.fromMap((m['pickup'] as Map?)?.cast<String, dynamic>()),
      dropoff:
          LatLngPoint.fromMap((m['dropoff'] as Map?)?.cast<String, dynamic>()),
      distanceMeters: (m['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
      routePolyline: m['routePolyline'] as String?,
      fare: Fare.fromMap((m['fare'] as Map?)?.cast<String, dynamic>()),
      startPin: m['startPin'] as String?,
      paymentMethod: PaymentMethod.fromId(m['paymentMethod'] as String?),
      captainLocation: m['captainLocation'] == null
          ? null
          : LatLngPoint.fromMap(
              (m['captainLocation'] as Map).cast<String, dynamic>()),
      customerLocation: m['customerLocation'] == null
          ? null
          : LatLngPoint.fromMap(
              (m['customerLocation'] as Map).cast<String, dynamic>()),
      parcelInfo: (m['parcelInfo'] as Map?)?.cast<String, dynamic>(),
      createdAt: _ts(m['createdAt']),
      acceptedAt: _ts(m['acceptedAt']),
      arrivedAt: _ts(m['arrivedAt']),
      startedAt: _ts(m['startedAt']),
      completedAt: _ts(m['completedAt']),
      cancelledAt: _ts(m['cancelledAt']),
      cancelledBy: m['cancelledBy'] as String?,
      cancelReason: m['cancelReason'] as String?,
      ratingByCustomer: m['ratingByCustomer'] == null
          ? null
          : RideRating.fromMap(
              (m['ratingByCustomer'] as Map).cast<String, dynamic>()),
      ratingByCaptain: m['ratingByCaptain'] == null
          ? null
          : RideRating.fromMap(
              (m['ratingByCaptain'] as Map).cast<String, dynamic>()),
    );
  }
}
