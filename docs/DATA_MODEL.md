# Flowzaa — Firestore Data Model

All realtime state lives in Cloud Firestore. Money is stored in **paise-free
rupees as numbers** (e.g. `48.5` = ₹48.50) for readability; round at display.

## Collections

### `users/{uid}` — customers (and the identity row for everyone)

```jsonc
{
  "uid": "abc123",
  "role": "customer",          // "customer" | "captain"
  "name": "Riya",
  "phone": "+919000000001",
  "email": null,
  "photoUrl": null,
  "fcmToken": "…",             // for push notifications
  "rating": 4.9,
  "ratingCount": 12,
  "savedPlaces": [             // optional favourites
    { "label": "Home", "address": "…", "lat": 17.44, "lng": 78.39 }
  ],
  "createdAt": <timestamp>,
  "updatedAt": <timestamp>
}
```

### `captains/{uid}` — captain profile + live availability

```jsonc
{
  "uid": "cap789",
  "name": "Arjun",
  "phone": "+919000000002",
  "photoUrl": null,
  "vehicleType": "bike",       // "bike" | "auto" | "car" | "parcel"
  "vehicleNumber": "TS09AB1234",
  "vehicleModel": "Honda Activa",
  "licenseNumber": "DLXX…",
  "upiId": "arjun@okhdfc",     // captain's OWN UPI — shown as QR to rider. 0% commission.
  "status": "approved",        // "pending_verification" | "approved" | "blocked"
  "isOnline": false,           // captain toggled availability
  "isAvailable": true,         // false while on an active ride
  "location": { "lat": 17.44, "lng": 78.39, "heading": 90 },
  "geohash": "tdr1x…",         // for future geo-queries
  "lastSeen": <timestamp>,
  "rating": 4.8,
  "ratingCount": 340,
  "totalRides": 512,
  "fcmToken": "…",
  "createdAt": <timestamp>,
  "updatedAt": <timestamp>
}
```

### `rides/{rideId}` — one document per ride, the heart of the realtime flow

```jsonc
{
  "id": "ride_…",
  "customerId": "abc123",
  "customerName": "Riya",
  "customerPhone": "+919000000001",
  "captainId": null,           // set when a captain accepts
  "captainName": null,
  "captainPhone": null,
  "captainVehicle": null,      // { type, number, model }

  "status": "searching",       // see state machine below
  "vehicleType": "bike",

  "pickup":  { "lat": 17.44, "lng": 78.39, "address": "Gachibowli" },
  "dropoff": { "lat": 17.49, "lng": 78.41, "address": "Hitech City" },

  "distanceMeters": 5300,
  "durationSeconds": 900,
  "routePolyline": "encoded…",

  "fare": {
    "base": 20, "distanceFare": 35.5, "timeFare": 9,
    "surge": 0, "total": 64.5, "currency": "INR"
  },

  "startPin": "4821",          // 4-digit; captain enters to start
  "paymentMethod": "cash",     // "cash" | "upi" — settled directly, 0% commission

  "captainLocation": { "lat": …, "lng": …, "heading": … }, // live during trip

  "createdAt": <ts>, "acceptedAt": <ts>, "arrivedAt": <ts>,
  "startedAt": <ts>, "completedAt": <ts>, "cancelledAt": <ts>,
  "cancelledBy": null,         // "customer" | "captain" | "system"
  "cancelReason": null,

  "ratingByCustomer": null,    // { stars, review }
  "ratingByCaptain": null
}
```

### `config/fares` — admin-editable pricing (single doc)

```jsonc
{
  "currency": "INR",
  "searchRadiusKm": 5,
  "types": {
    "bike":   { "base": 20, "perKm": 6.5, "perMin": 0.6, "min": 25 },
    "auto":   { "base": 30, "perKm": 9,   "perMin": 0.8, "min": 35 },
    "car":    { "base": 50, "perKm": 14,  "perMin": 1.2, "min": 70 },
    "parcel": { "base": 25, "perKm": 8,   "perMin": 0.7, "min": 30 }
  }
}
```

## Ride state machine

```
                cancel (customer/captain)
   ┌─────────────────────────────────────────────┐
   ▼                                              │
searching ──accept──▶ accepted ──arrive──▶ arrived ──PIN ok──▶ ongoing ──complete──▶ completed
   │                                                                                     
   └── (no captain, timeout) ──▶ expired
```

- **searching** — ride created, waiting for a captain. Online captains of the
  matching `vehicleType` within `searchRadiusKm` see it.
- **accepted** — a captain claimed it (atomic transaction: only if still
  `searching`). Captain heads to pickup.
- **arrived** — captain reached pickup; rider is notified.
- **ongoing** — captain entered the correct `startPin`; trip in progress; live
  `captainLocation` updates.
- **completed** — captain ended the trip; fare finalised; payment is direct
  (cash / captain UPI QR). Ratings enabled.
- **cancelled** / **expired** — terminal.

## Matching strategy (MVP)

To avoid heavy geo-query infrastructure on day one:

- The **customer** writes a `searching` ride.
- Online **captains** subscribe to `rides where status == "searching" &&
  vehicleType == <theirs>`, then filter by distance client-side (Haversine vs
  their own location) and by freshness.
- A captain **accepts** via a Firestore transaction that flips `status` to
  `accepted` and sets `captainId` **only if** the ride is still `searching` —
  guaranteeing exactly one captain wins.
- A Cloud Function (`onRideCreated`) additionally sends **FCM** to nearby
  captains and generates the `startPin`; another (`expireStaleRides`, scheduled)
  marks old `searching` rides as `expired`.

This is documented so it can later be upgraded to GeoFirestore / a dedicated
dispatch service without changing the app contract.
