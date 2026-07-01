/**
 * Flowzaa Cloud Functions
 *
 * Responsibilities the client must not be trusted with:
 *   - Generate the 4-digit ride Start-PIN.
 *   - Fan out FCM notifications to nearby captains when a ride is requested,
 *     and to the relevant party on every status change.
 *   - Maintain captain counters (rides, availability) on completion/cancel.
 *   - Seed & expose default fare config.
 *   - Expire stale "searching" rides on a schedule.
 *
 * Flowzaa takes 0% commission — there is no payment/ledger logic here by design.
 */

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

// ---------------------------------------------------------------------------
// Defaults (India, ₹). Editable in Firestore at config/fares afterwards.
// ---------------------------------------------------------------------------
const DEFAULT_FARES = {
  currency: "INR",
  searchRadiusKm: 5,
  types: {
    bike: { base: 20, perKm: 6.5, perMin: 0.6, min: 25 },
    auto: { base: 30, perKm: 9, perMin: 0.8, min: 35 },
    car: { base: 50, perKm: 14, perMin: 1.2, min: 70 },
    parcel: { base: 25, perKm: 8, perMin: 0.7, min: 30 },
  },
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function generatePin() {
  // 1000–9999, avoids leading-zero ambiguity for the captain's keypad.
  return String(1000 + Math.floor(Math.random() * 9000));
}

function haversineKm(a, b) {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function getFares() {
  const snap = await db.doc("config/fares").get();
  return snap.exists ? snap.data() : DEFAULT_FARES;
}

async function sendToToken(token, notification, data) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification,
      data: data || {},
      android: { priority: "high" },
      apns: { headers: { "apns-priority": "10" } },
    });
  } catch (err) {
    logger.warn("FCM send failed", err.message);
  }
}

// ---------------------------------------------------------------------------
// onRideCreated: stamp the Start-PIN, then notify nearby available captains.
// ---------------------------------------------------------------------------
exports.onRideCreated = onDocumentCreated("rides/{rideId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const ride = snap.data();
  if (ride.status !== "searching") return;

  // 1) Server-authoritative Start-PIN (client never generates it).
  const startPin = ride.startPin || generatePin();
  await snap.ref.update({ startPin });

  // 2) Notify nearby online + available captains of the matching type.
  const fares = await getFares();
  const radiusKm = fares.searchRadiusKm || 5;
  const pickup = ride.pickup;

  const captainsSnap = await db
    .collection("captains")
    .where("vehicleType", "==", ride.vehicleType)
    .where("isOnline", "==", true)
    .where("isAvailable", "==", true)
    .get();

  const targets = [];
  captainsSnap.forEach((doc) => {
    const c = doc.data();
    if (!c.location || !c.fcmToken) return;
    const dist = haversineKm(pickup, c.location);
    if (dist <= radiusKm) targets.push({ token: c.fcmToken, dist });
  });

  targets.sort((a, b) => a.dist - b.dist);
  logger.info(`Ride ${event.params.rideId}: notifying ${targets.length} captains`);

  await Promise.all(
    targets.slice(0, 20).map((t) =>
      sendToToken(
        t.token,
        {
          title: "New ride request 🛵",
          body: `${ride.vehicleType.toUpperCase()} · ₹${Math.round(
            ride.fare?.total || 0
          )} · ${(ride.distanceMeters / 1000).toFixed(1)} km`,
        },
        { type: "new_ride", rideId: event.params.rideId }
      )
    )
  );
});

// ---------------------------------------------------------------------------
// onRideUpdated: notify the right party on each status transition, and keep
// captain availability/counters correct.
// ---------------------------------------------------------------------------
exports.onRideUpdated = onDocumentUpdated("rides/{rideId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return; // only care about transitions

  const [customerSnap, captainSnap] = await Promise.all([
    after.customerId ? db.doc(`users/${after.customerId}`).get() : null,
    after.captainId ? db.doc(`captains/${after.captainId}`).get() : null,
  ]);
  const customerToken = customerSnap?.exists ? customerSnap.data().fcmToken : null;

  switch (after.status) {
    case "accepted":
      await sendToToken(
        customerToken,
        { title: "Captain on the way 🚀", body: `${after.captainName || "Your captain"} accepted your ride.` },
        { type: "ride_accepted", rideId: event.params.rideId }
      );
      break;

    case "arrived":
      await sendToToken(
        customerToken,
        { title: "Captain has arrived 📍", body: `Share your PIN ${after.startPin} to start the ride.` },
        { type: "ride_arrived", rideId: event.params.rideId }
      );
      break;

    case "ongoing":
      await sendToToken(
        customerToken,
        { title: "Ride started ✅", body: "Enjoy your trip with Flowzaa." },
        { type: "ride_started", rideId: event.params.rideId }
      );
      break;

    case "completed":
      if (after.captainId) {
        await db.doc(`captains/${after.captainId}`).set(
          {
            isAvailable: true,
            totalRides: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
      await sendToToken(
        customerToken,
        { title: "Ride completed 🎉", body: `Fare ₹${Math.round(after.fare?.total || 0)} · pay directly by ${after.paymentMethod === "upi" ? "UPI QR" : "cash"}.` },
        { type: "ride_completed", rideId: event.params.rideId }
      );
      break;

    case "cancelled":
    case "expired":
      // Free the captain if one was assigned.
      if (after.captainId) {
        await db.doc(`captains/${after.captainId}`).set(
          { isAvailable: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true }
        );
      }
      // Tell the *other* party who cancelled.
      if (after.cancelledBy === "captain") {
        await sendToToken(
          customerToken,
          { title: "Ride cancelled", body: "Your captain cancelled. Please rebook." },
          { type: "ride_cancelled", rideId: event.params.rideId }
        );
      } else if (after.cancelledBy === "customer" && captainSnap?.exists) {
        await sendToToken(
          captainSnap.data().fcmToken,
          { title: "Ride cancelled", body: "The customer cancelled the ride." },
          { type: "ride_cancelled", rideId: event.params.rideId }
        );
      }
      break;
  }
});

// ---------------------------------------------------------------------------
// expireStaleRides: mark long-unmatched "searching" rides as expired.
// ---------------------------------------------------------------------------
exports.expireStaleRides = onSchedule("every 2 minutes", async () => {
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 3 * 60 * 1000);
  const stale = await db
    .collection("rides")
    .where("status", "==", "searching")
    .where("createdAt", "<", cutoff)
    .get();

  const batch = db.batch();
  stale.forEach((doc) =>
    batch.update(doc.ref, {
      status: "expired",
      cancelledBy: "system",
      cancelReason: "No captain found nearby",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    })
  );
  if (!stale.empty) {
    await batch.commit();
    logger.info(`Expired ${stale.size} stale rides`);
  }
});

// ---------------------------------------------------------------------------
// seedFares (callable): write default fares. Run once from an admin device or
// let the app call it on first launch (idempotent — won't overwrite if present).
// ---------------------------------------------------------------------------
exports.seedFares = onCall(async (request) => {
  const ref = db.doc("config/fares");
  const existing = await ref.get();
  if (existing.exists && !request.data?.force) {
    return { seeded: false, message: "Fares already exist" };
  }
  await ref.set(DEFAULT_FARES);
  return { seeded: true, fares: DEFAULT_FARES };
});
