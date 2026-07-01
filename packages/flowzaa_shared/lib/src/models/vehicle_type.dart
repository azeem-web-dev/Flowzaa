/// The ride categories Flowzaa offers.
enum VehicleType {
  bike,
  auto,
  car,
  parcel;

  static VehicleType fromId(String? id) {
    switch (id) {
      case 'bike':
        return VehicleType.bike;
      case 'auto':
        return VehicleType.auto;
      case 'car':
        return VehicleType.car;
      case 'parcel':
        return VehicleType.parcel;
      default:
        return VehicleType.bike;
    }
  }

  String get id => name;

  String get label {
    switch (this) {
      case VehicleType.bike:
        return 'Bike';
      case VehicleType.auto:
        return 'Auto';
      case VehicleType.car:
        return 'Car';
      case VehicleType.parcel:
        return 'Parcel';
    }
  }

  String get description {
    switch (this) {
      case VehicleType.bike:
        return 'Quick & affordable';
      case VehicleType.auto:
        return 'Comfy three-wheeler';
      case VehicleType.car:
        return 'Ride in comfort';
      case VehicleType.parcel:
        return 'Send a package';
    }
  }

  /// Emoji used as a lightweight icon across both apps.
  String get emoji {
    switch (this) {
      case VehicleType.bike:
        return '🏍️';
      case VehicleType.auto:
        return '🛺';
      case VehicleType.car:
        return '🚗';
      case VehicleType.parcel:
        return '📦';
    }
  }

  /// Typical seating capacity, shown on the selector.
  int get capacity {
    switch (this) {
      case VehicleType.bike:
        return 1;
      case VehicleType.auto:
        return 3;
      case VehicleType.car:
        return 4;
      case VehicleType.parcel:
        return 0;
    }
  }
}
