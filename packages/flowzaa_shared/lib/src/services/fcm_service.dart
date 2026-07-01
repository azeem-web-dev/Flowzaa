import 'package:firebase_messaging/firebase_messaging.dart';

/// Cloud Messaging registration. Each app calls [init] after sign-in and
/// persists the token onto the user's/captain's profile (via AuthService).
class FcmService {
  final _messaging = FirebaseMessaging.instance;

  Future<String?> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return _messaging.getToken();
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Foreground messages (show your own in-app banner from these).
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// Taps on a notification that opened the app.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
