/// Lifecycle of a ride. See docs/DATA_MODEL.md for the state machine.
enum RideStatus {
  searching,
  accepted,
  arrived,
  ongoing,
  completed,
  cancelled,
  expired;

  static RideStatus fromId(String? id) {
    return RideStatus.values.firstWhere(
      (s) => s.name == id,
      orElse: () => RideStatus.searching,
    );
  }

  String get id => name;

  bool get isActive =>
      this == searching ||
      this == accepted ||
      this == arrived ||
      this == ongoing;

  bool get isTerminal =>
      this == completed || this == cancelled || this == expired;

  String get customerLabel {
    switch (this) {
      case RideStatus.searching:
        return 'Finding you a captain…';
      case RideStatus.accepted:
        return 'Captain is on the way';
      case RideStatus.arrived:
        return 'Captain has arrived';
      case RideStatus.ongoing:
        return 'On the way to destination';
      case RideStatus.completed:
        return 'Ride completed';
      case RideStatus.cancelled:
        return 'Ride cancelled';
      case RideStatus.expired:
        return 'No captain found';
    }
  }

  String get captainLabel {
    switch (this) {
      case RideStatus.searching:
        return 'New request';
      case RideStatus.accepted:
        return 'Head to pickup';
      case RideStatus.arrived:
        return 'Waiting for rider · enter PIN';
      case RideStatus.ongoing:
        return 'Trip in progress';
      case RideStatus.completed:
        return 'Trip completed';
      case RideStatus.cancelled:
        return 'Cancelled';
      case RideStatus.expired:
        return 'Expired';
    }
  }
}
