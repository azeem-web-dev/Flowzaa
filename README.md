# Flowzaa 🛵

A commission-free, Rapido-style ride-hailing platform. Two Flutter apps (a
**Customer** app and a **Captain/rider** app) backed by **Firebase** and
**Google Maps**, with live location tracking, fare estimates, a 4-digit ride
Start-PIN, and **0% commission** — fares go directly to the captain via cash or
their own UPI QR.

> Flowzaa takes **no cut**. Payment is settled directly between rider and
> captain (cash or the captain's own UPI QR). There is no in-app payment
> gateway and no wallet.

---

## Monorepo layout

```
Flowzaa/
├── apps/
│   ├── customer/          # Flutter app for riders (book a ride)
│   └── captain/           # Flutter app for captains (accept & drive)
├── packages/
│   └── flowzaa_shared/    # Shared Dart package: models, services, theme, fare logic
├── firebase/
│   ├── firebase.json
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── functions/         # Cloud Functions: pricing config, matching, FCM notifications
└── docs/
    ├── SETUP.md           # ← START HERE: step-by-step Firebase + Google Maps setup
    ├── ARCHITECTURE.md
    └── DATA_MODEL.md
```

## Ride types

| Type   | Description            |
|--------|------------------------|
| Bike   | Two-wheeler taxi       |
| Auto   | Three-wheeler auto     |
| Car    | Four-wheeler cab       |
| Parcel | Package delivery       |

## The ride flow (end-to-end)

1. **Login** — phone number + OTP (Firebase Phone Auth).
2. **Set pickup & drop** — current location is auto-detected; search or tap the
   map to set both points.
3. **Choose ride type & see fare** — Bike/Auto/Car/Parcel, each with a live
   distance + ETA + fare estimate (base + per-km + per-min).
4. **Request ride** — a 4-digit **Start-PIN** is generated for the rider.
5. **Captain matches** — nearby online captains of that type see the request,
   and one accepts it (first-come, atomic).
6. **Live tracking** — rider watches the captain approach in real time; both
   see distance/ETA.
7. **Start-PIN** — captain enters the rider's 4-digit PIN to start the trip.
8. **Complete** — captain ends the trip; fare is shown; rider pays **cash or
   captain's UPI QR** directly. Both can rate each other.
9. **Cancel** — either side can cancel before start, with a reason.

## Getting started

👉 **Read [`docs/SETUP.md`](docs/SETUP.md) first.** It walks you click-by-click
through creating the Firebase project and Google Maps key (the two things I
can't create for you), then running both apps.

Quick version once credentials are in place:

```bash
# Shared package deps resolve automatically via path dependency.
cd apps/customer && flutter pub get && flutter run
# in another terminal:
cd apps/captain  && flutter pub get && flutter run
```

## Tech stack

- **Frontend:** Flutter 3.x (Dart), Riverpod for state, google_maps_flutter, geolocator
- **Backend:** Firebase — Phone Auth, Cloud Firestore (realtime), Cloud
  Messaging (FCM), Cloud Functions (Node.js)
- **Maps/Routing:** Google Maps Platform — Maps SDK, Places, Directions,
  Distance Matrix

## Status

This is the initial build. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
for what's implemented and the roadmap.
