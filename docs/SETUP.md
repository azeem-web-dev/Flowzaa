# Flowzaa — Setup Guide

This guide walks you, click-by-click, through the two things I can't create for
you — a **Firebase project** and a **Google Maps API key** — and then how to run
both apps.

Budget ~30 minutes. You'll need a Google account and, for Google Maps, a credit
card for billing (Google gives a large free monthly credit; a demo app costs
₹0).

---

## 0. Prerequisites (install once)

| Tool | Why | Install |
|------|-----|---------|
| Flutter SDK 3.19+ | Build the apps | https://docs.flutter.dev/get-started/install |
| Android Studio / Xcode | Emulator + SDKs | Comes with Flutter setup |
| Node.js 18+ | Cloud Functions + Firebase CLI | https://nodejs.org |
| Firebase CLI | Deploy backend | `npm install -g firebase-tools` |
| FlutterFire CLI | Wire Flutter ↔ Firebase | `dart pub global activate flutterfire_cli` |

Verify: `flutter doctor` should be all green for Android at least.

---

## 1. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project**.
2. Name it `flowzaa` (or anything). Continue.
3. Disable Google Analytics for now (optional). **Create project**.

### 1a. Enable Phone Authentication

1. In the console: **Build → Authentication → Get started**.
2. **Sign-in method** tab → **Phone** → **Enable** → Save.
3. (For testing without real SMS) Under Phone, expand **Phone numbers for
   testing** and add e.g. `+91 9000000001` with code `123456`. Do this for a
   couple of numbers so you can log into the customer AND captain app.

### 1b. Create the Firestore database

1. **Build → Firestore Database → Create database**.
2. Start in **production mode** (we ship real security rules). Pick a region
   close to you (e.g. `asia-south1` for India). Enable.

### 1c. Enable Cloud Messaging

Cloud Messaging is on by default once the project exists — no action needed. FCM
tokens are handled in-app.

---

## 2. Get a Google Maps API key

1. The Firebase project **is** a Google Cloud project. Open
   https://console.cloud.google.com and select the `flowzaa` project (top bar).
2. **APIs & Services → Enable APIs and Services**. Enable each of these:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** (only if building for iOS)
   - **Places API** (address search / autocomplete)
   - **Directions API** (route polyline)
   - **Distance Matrix API** (distance + ETA for fares)
   - **Geocoding API** (reverse-geocode current location → address)
3. **APIs & Services → Credentials → Create credentials → API key.**
4. Copy the key. Click **Edit** on it and, for production, restrict it:
   - Application restriction: Android apps → add each app's package name +
     SHA-1 (get SHA-1 with `cd apps/customer/android && ./gradlew signingReport`).
   - API restriction: limit to the 6 APIs above.
   - For first-run testing you can leave it unrestricted, but **re-restrict
     before shipping**.
5. **Enable Billing** (APIs & Services will prompt): Cloud Console →
   **Billing → Link a billing account**. Required even for the free tier.

You now have **one** Maps key. We'll put it in a few places below.

---

## 3. Wire Firebase into the two Flutter apps

The FlutterFire CLI generates a `firebase_options.dart` and the native config
files (`google-services.json` / `GoogleService-Info.plist`) automatically.

Run it **once per app**:

```bash
cd apps/customer
flutterfire configure --project=flowzaa
#   → select platforms (Android, iOS). It registers the apps and writes
#     lib/firebase_options.dart + android/app/google-services.json

cd ../captain
flutterfire configure --project=flowzaa
```

Register the two apps with **distinct package names** when prompted, e.g.:
- Customer: `com.flowzaa.customer`
- Captain:  `com.flowzaa.captain`

---

## 4. Drop in the Google Maps key

The key is referenced from env-style placeholders. Replace `YOUR_MAPS_API_KEY`
in these files:

**Android** — `apps/customer/android/app/src/main/AndroidManifest.xml` and the
same file under `apps/captain/`:

```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_MAPS_API_KEY"/>
```

**iOS** — `apps/customer/ios/Runner/AppDelegate.swift` (and captain):

```swift
GMSServices.provideAPIKey("YOUR_MAPS_API_KEY")
```

**Dart (Places/Directions HTTP calls)** — create `apps/customer/.env` and
`apps/captain/.env` from the provided `.env.example`:

```
MAPS_API_KEY=YOUR_MAPS_API_KEY
```

> `.env` files are git-ignored. Never commit real keys.

---

## 5. Deploy the backend (Firestore rules + Cloud Functions)

```bash
cd firebase
firebase use flowzaa            # or: firebase use --add
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions
```

This publishes the security rules, the composite indexes, and the Cloud
Functions (fare seeding, PIN generation, matching notifications).

### Seed the fare config

The first deploy runs a callable/one-off that writes default fares to
`config/fares`. If you prefer, set them by hand in Firestore → `config/fares`
(see `docs/DATA_MODEL.md` for the shape). Defaults (₹, India) ship in the
function.

---

## 6. Run the apps

```bash
# Terminal 1 — customer
cd apps/customer && flutter pub get && flutter run

# Terminal 2 — captain
cd apps/captain && flutter pub get && flutter run
```

Log into the **captain** app with one test number, go **Online**, fill the
vehicle details. Log into the **customer** app with another test number, set
pickup + drop, pick a ride type, and request. The captain will see the request,
accept, enter the 4-digit PIN the customer shows, drive, and complete. 🎉

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Map is blank/grey | Maps SDK not enabled, key wrong, or billing not linked. Check step 2 + 4. |
| OTP never arrives | Use a **test phone number** (step 1a) during development. |
| `PERMISSION_DENIED` in Firestore | Rules not deployed (step 5) or you're using a mismatched role. |
| `MISSING_INDEX` error with a link | Click the link to auto-create it, or run the indexes deploy in step 5. |
| Location is (0,0) | Grant location permission on the device/emulator; set a mock location in the emulator. |

Once real keys are in, tell me and I'll help you test the full loop.
