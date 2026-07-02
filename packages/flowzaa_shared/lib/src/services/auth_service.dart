import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'firestore_refs.dart';

/// Phone-OTP authentication + the current user's profile row.
///
/// Usage:
///   1. [sendOtp] → get a verificationId (via callbacks).
///   2. [verifyOtp] with the code the user typed.
///   3. [ensureUserProfile] / [ensureCaptainProfile] to create the row.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Firebase console test numbers (Authentication → Phone → test numbers).
  /// OTP for these is 123456; no SMS is sent and no app verification runs.
  static const testNumbers = {'+919000000001', '+919000000002'};

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Kicks off phone verification. On Android, [onAutoVerified] may fire when
  /// the SMS is auto-read; otherwise [onCodeSent] provides the verificationId.
  Future<void> sendOtp({
    required String phoneNumber, // E.164, e.g. +919000000001
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final isTest = testNumbers.contains(phoneNumber);
    // On sideloaded release builds the default Play Integrity device check can
    // hang forever (no callback fires). Forcing the reCAPTCHA flow avoids Play
    // Integrity entirely and works on any build. Test numbers are fictional, so
    // they short-circuit before any verification and sign in instantly.
    await _auth.setSettings(
      appVerificationDisabledForTesting: isTest,
      forceRecaptchaFlow: true,
    );
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: (credential) {
        onAutoVerified?.call(credential);
      },
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Completes sign-in with the 6-digit SMS code.
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithCredential(PhoneAuthCredential c) =>
      _auth.signInWithCredential(c);

  /// Streams the signed-in customer's profile (null while signed out).
  Stream<AppUser?> userProfileStream() {
    final id = uid;
    if (id == null) return const Stream.empty();
    return Refs.user(id).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
  }

  Future<AppUser?> fetchUserProfile() async {
    final id = uid;
    if (id == null) return null;
    final doc = await Refs.user(id).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  /// Creates the customer profile row if missing; updates name/token if given.
  Future<AppUser> ensureUserProfile({String? name, String? fcmToken}) async {
    final u = _auth.currentUser!;
    final ref = Refs.user(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final profile = AppUser(
        uid: u.uid,
        role: UserRole.customer,
        name: name ?? 'Rider',
        phone: u.phoneNumber ?? '',
        fcmToken: fcmToken,
      );
      await ref.set(profile.toMap()..['createdAt'] = DateTime.now());
      return profile;
    }
    if (name != null || fcmToken != null) {
      await ref.set({
        if (name != null) 'name': name,
        if (fcmToken != null) 'fcmToken': fcmToken,
      }, SetOptions(merge: true));
    }
    return AppUser.fromDoc(await ref.get());
  }

  /// Replace the user's saved places (Home/Work shortcuts).
  Future<void> saveSavedPlaces(List<SavedPlace> places) async {
    final id = uid;
    if (id == null) return;
    await Refs.user(id).set({
      'savedPlaces': places.map((p) => p.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  /// Update the display name on the profile.
  Future<void> updateName(String name) async {
    final id = uid;
    if (id == null) return;
    await Refs.user(id).set({'name': name}, SetOptions(merge: true));
  }

  Future<void> updateFcmToken(String token, {bool captain = false}) async {
    final id = uid;
    if (id == null) return;
    final ref = captain ? Refs.captain(id) : Refs.user(id);
    await ref.set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();

  /// Human-friendly, actionable message for phone-auth failures.
  static String friendlyError(FirebaseAuthException e) {
    final raw = e.message ?? '';
    if (raw.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Phone sign-in is not enabled for this Firebase project yet. '
          'In Firebase console: Authentication → Get started → Sign-in '
          'method → Phone → Enable.';
    }
    switch (e.code) {
      case 'app-not-authorized':
      case 'missing-client-identifier':
        return 'This build is not authorized for phone sign-in. Add the '
            "app's SHA-1 fingerprint in Firebase console (Project settings "
            '→ Your apps), or use a test number.';
      case 'invalid-phone-number':
        return 'That phone number looks invalid. Use a 10-digit mobile number.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts from this device. Wait a few minutes and '
            'try again, or use a test number.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Check the code and try again.';
      case 'session-expired':
        return 'This OTP expired. Request a new code.';
    }
    return raw.isEmpty ? 'Verification failed (${e.code}).' : raw;
  }
}
