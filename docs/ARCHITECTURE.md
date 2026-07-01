# Flowzaa — Architecture

## High-level

```
┌────────────────┐        ┌────────────────┐
│  Customer app  │        │  Captain app   │
│   (Flutter)    │        │   (Flutter)    │
└───────┬────────┘        └───────┬────────┘
        │   both depend on        │
        └────────┬───────────────┘
                 ▼
     ┌────────────────────────┐
     │   flowzaa_shared pkg   │  models · services · theme · fare · widgets
     └───────────┬────────────┘
                 ▼
     ┌────────────────────────────────────────────┐
     │                 Firebase                     │
     │  Phone Auth · Firestore(realtime) · FCM      │
     │  Cloud Functions (fares · matching · PIN)    │
     └───────────────────┬──────────────────────────┘
                         ▼
             ┌────────────────────────┐
             │  Google Maps Platform  │
             │  Maps · Places ·        │
             │  Directions · Distance  │
             └────────────────────────┘
```

## Why this shape

- **Shared Dart package (`flowzaa_shared`)** keeps the two apps in lock-step:
  one source of truth for the `Ride`/`Captain`/`Fare` models, the Firestore
  service layer, the fare formula, the theme, and reusable widgets. Change a
  field once, both apps stay consistent.
- **Firestore as the realtime bus.** The ride document is a shared state
  machine; both apps `snapshots()`-subscribe to it. No custom WebSocket server
  to run — the "live tracking" is just the captain writing their location to the
  ride doc and the customer streaming it.
- **Cloud Functions for anything the client shouldn't be trusted with**: fare
  config seeding, generating the Start-PIN, fan-out FCM to nearby captains, and
  expiring stale requests.
- **0% commission by design.** No payment gateway, no wallet, no ledger that
  takes a cut. `paymentMethod` is `cash` or `upi`, settled directly; the app
  only records which method was used.

## State management

Flutter **Riverpod** (`flutter_riverpod`). Providers wrap the shared services
(auth stream, ride stream, location stream). UI watches providers; no
`setState` spaghetti.

Key providers (in each app's `lib/providers/`):
- `authStateProvider` — Firebase user + role.
- `currentRideProvider` — `StreamProvider` of the active ride doc.
- `nearbyRequestsProvider` (captain) — `StreamProvider` of `searching` rides.
- `locationProvider` — device GPS stream.

## Package layout (`flowzaa_shared`)

```
lib/
  flowzaa_shared.dart          # barrel export
  src/
    models/                    # Ride, AppUser, Captain, LatLngPoint, Fare, VehicleType, enums
    services/
      auth_service.dart        # phone OTP sign-in, profile
      ride_service.dart        # create/accept/arrive/start/complete/cancel + streams
      captain_service.dart     # online toggle, location push, profile
      location_service.dart    # geolocator wrapper (permission, stream)
      maps_service.dart        # Places autocomplete, Directions, Distance Matrix, geocode
      fcm_service.dart         # token registration
    fare/
      fare_calculator.dart     # base + perKm + perMin + min, from config
    theme/
      app_theme.dart, app_colors.dart, app_text.dart
    widgets/                   # buttons, ride-type tile, primary sheet, avatar, etc.
    utils/                     # geo (haversine), formatters, pin, result types
```

## The realtime ride loop (who writes what)

| Step | Customer app writes | Captain app writes | Cloud Function |
|------|--------------------|--------------------|----------------|
| Request | `rides/{id}` status=`searching`, fare, pins req | — | `onRideCreated`: set `startPin`, FCM nearby captains |
| Accept | — | txn: status=`accepted`, captainId, `isAvailable=false` | `onRideAccepted`: FCM customer |
| En route | streams captainLocation | writes `captainLocation` every few s | — |
| Arrived | — | status=`arrived` | FCM customer |
| Start | shows PIN | verifies PIN → status=`ongoing` | — |
| Complete | — | status=`completed`, `isAvailable=true` | `onRideCompleted`: bump counters |
| Cancel | status=`cancelled` | or status=`cancelled` | free the captain |

## Security

- Firestore rules (`firebase/firestore.rules`): a user can only read/write their
  own `users`/`captains` doc; ride writes are constrained to the participants and
  to valid state transitions; `config/fares` is read-only to clients.
- Start-PIN prevents wrong-rider pickups; it's generated server-side and only
  the customer sees it in-app.
- Maps key is restricted by package name + API (see SETUP §2).

## What's implemented in this build

- [x] Monorepo + shared package with full model & service layer
- [x] Firebase rules, indexes, Cloud Functions (fares, PIN, matching FCM, expiry)
- [x] Customer app: OTP login, map + pickup/drop search, ride-type & fare,
      request, live tracking, PIN, complete, cancel, rate
- [x] Captain app: OTP login, profile/vehicle, online toggle, incoming
      requests, accept, navigate, Start-PIN, complete, earnings summary
- [x] Fare engine, theme/design system, reusable widgets

## Roadmap (next milestones)

- [ ] GeoFirestore-backed dispatch + sequential offer (instead of broadcast)
- [ ] In-app chat & call masking
- [ ] Scheduled rides, ride history screen, favourites
- [ ] Captain document verification + admin web console
- [ ] Surge pricing, promo codes
- [ ] Automated tests (unit for fare/geo, widget, integration)
- [ ] CI (GitHub Actions: analyze + test + build)
