/// Flowzaa shared library — models, services, fare engine, theme & widgets used
/// by both the customer and captain apps.
library flowzaa_shared;

// Models
export 'src/models/app_user.dart';
export 'src/models/captain.dart';
export 'src/models/fare.dart';
export 'src/models/lat_lng_point.dart';
export 'src/models/place.dart';
export 'src/models/ride.dart';
export 'src/models/ride_status.dart';
export 'src/models/vehicle_type.dart';

// Fare engine
export 'src/fare/fare_calculator.dart';
export 'src/fare/fare_config.dart';

// Services
export 'src/services/auth_service.dart';
export 'src/services/captain_service.dart';
export 'src/services/fcm_service.dart';
export 'src/services/firestore_refs.dart';
export 'src/services/geo_gateway.dart';
export 'src/services/location_service.dart';
export 'src/services/maps_service.dart';
export 'src/services/osm_geo_gateway.dart';
export 'src/services/ride_service.dart';

// Theme
export 'src/theme/app_colors.dart';
export 'src/theme/app_text.dart';
export 'src/theme/app_theme.dart';

// Utils
export 'src/utils/formatters.dart';
export 'src/utils/geo.dart';

// Widgets
export 'src/widgets/info_pill.dart';
export 'src/widgets/primary_button.dart';
export 'src/widgets/rating_stars.dart';
export 'src/widgets/vehicle_type_tile.dart';
