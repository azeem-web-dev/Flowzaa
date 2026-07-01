#!/usr/bin/env bash
#
# Flowzaa — one-shot Firebase / Google Cloud provisioning for Cloud Shell.
#
# Run this INSIDE Google Cloud Shell (it's already logged into your account).
# It enables the required APIs, creates the Firestore database, turns on Phone
# Auth with test numbers, creates a Google Maps API key, registers the two
# Android apps, downloads their google-services.json, and (if billing is on)
# deploys the Firestore rules + Cloud Functions.
#
# Usage:
#   git clone https://github.com/azeem-web-dev/Flowzaa.git
#   cd Flowzaa
#   bash scripts/setup_firebase.sh
#
# It's safe to re-run — every step is idempotent.

set -uo pipefail

PROJECT="flowzaa-7c9d8"
REGION="asia-south1"
CUSTOMER_PKG="com.flowzaa.customer"
CAPTAIN_PKG="com.flowzaa.captain"

bold(){ printf "\n\033[1;36m==> %s\033[0m\n" "$1"; }
ok(){   printf "\033[1;32m  ✓ %s\033[0m\n" "$1"; }
warn(){ printf "\033[1;33m  ! %s\033[0m\n" "$1"; }

bold "Setting active project to $PROJECT"
gcloud config set project "$PROJECT" -q

# ---------------------------------------------------------------------------
bold "1/6  Enabling Google Cloud APIs (one at a time, so one failure can't block the rest)"
APIS=(
  firestore.googleapis.com
  identitytoolkit.googleapis.com
  cloudfunctions.googleapis.com
  cloudbuild.googleapis.com
  run.googleapis.com
  eventarc.googleapis.com
  fcm.googleapis.com
  apikeys.googleapis.com
  maps-android-backend.googleapis.com
  maps-ios-backend.googleapis.com
  places-backend.googleapis.com
  directions-backend.googleapis.com
  distance-matrix-backend.googleapis.com
  geocoding-backend.googleapis.com
)
for api in "${APIS[@]}"; do
  if gcloud services enable "$api" -q 2>/dev/null; then
    ok "enabled $api"
  else
    warn "could not enable $api (will retry on next run / may need Blaze)"
  fi
done

# ---------------------------------------------------------------------------
bold "2/6  Creating Firestore database ($REGION, native mode)"
if gcloud firestore databases describe --database="(default)" >/dev/null 2>&1; then
  ok "Firestore already exists"
else
  gcloud firestore databases create --location="$REGION" -q && ok "Firestore created"
fi

# ---------------------------------------------------------------------------
bold "3/6  Enabling Phone Authentication + test numbers"
TOKEN="$(gcloud auth print-access-token)"
curl -s -X PATCH \
  "https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT}/config?updateMask=signIn.phoneNumber" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
        "signIn": {
          "phoneNumber": {
            "enabled": true,
            "testPhoneNumbers": {
              "+919000000001": "123456",
              "+919000000002": "123456"
            }
          }
        }
      }' >/dev/null && ok "Phone Auth ON (test: +919000000001 / +919000000002 → 123456)"

# ---------------------------------------------------------------------------
bold "4/6  Creating a Google Maps API key"
EXISTING_KEY_ID="$(gcloud services api-keys list --filter="displayName='Flowzaa Maps Key'" --format='value(uid)' 2>/dev/null | head -1)"
if [ -z "$EXISTING_KEY_ID" ]; then
  gcloud services api-keys create --display-name="Flowzaa Maps Key" -q >/dev/null 2>&1
  EXISTING_KEY_ID="$(gcloud services api-keys list --filter="displayName='Flowzaa Maps Key'" --format='value(uid)' 2>/dev/null | head -1)"
fi
MAPS_KEY="$(gcloud services api-keys get-key-string "$EXISTING_KEY_ID" --format='value(keyString)' 2>/dev/null)"
if [ -n "$MAPS_KEY" ]; then
  echo "$MAPS_KEY" > "$HOME/flowzaa-maps-key.txt"
  ok "Maps key created → saved to ~/flowzaa-maps-key.txt"
else
  warn "Could not read Maps key string — create one in the console instead."
fi

# ---------------------------------------------------------------------------
bold "5/6  Registering the two Android apps"
register_app () {
  local pkg="$1" ; local out="$2"
  local id
  id="$(firebase apps:list ANDROID --project "$PROJECT" 2>/dev/null | grep "$pkg" | awk -F'│' '{print $3}' | tr -d ' ')"
  if [ -z "$id" ]; then
    firebase apps:create ANDROID "$pkg" --package-name "$pkg" --project "$PROJECT" >/dev/null 2>&1
    id="$(firebase apps:list ANDROID --project "$PROJECT" 2>/dev/null | grep "$pkg" | awk -F'│' '{print $3}' | tr -d ' ')"
  fi
  if [ -n "$id" ]; then
    firebase apps:sdkconfig ANDROID "$id" --project "$PROJECT" --out "$out" >/dev/null 2>&1
    ok "$pkg → $id  (config: $out)"
  else
    warn "Could not register $pkg (is 'firebase login' done?)"
  fi
}
mkdir -p apps/customer/android/app apps/captain/android/app
register_app "$CUSTOMER_PKG" "apps/customer/android/app/google-services.json"
register_app "$CAPTAIN_PKG"  "apps/captain/android/app/google-services.json"

# ---------------------------------------------------------------------------
bold "6/6  Deploying Firestore rules, indexes & Cloud Functions"
if gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)' 2>/dev/null | grep -qi true; then
  ( cd firebase/functions && npm install >/dev/null 2>&1 )
  ( cd firebase && firebase deploy --only firestore:rules,firestore:indexes,functions --project "$PROJECT" )
  ok "Backend deployed"
else
  warn "Billing (Blaze plan) is NOT enabled — skipping Functions deploy."
  warn "Google Maps AND Cloud Functions both need Blaze. Enable it here:"
  warn "  https://console.firebase.google.com/project/${PROJECT}/usage/details"
  warn "Then re-run this script (it will pick up from here)."
  # Rules + indexes don't need Blaze:
  ( cd firebase && firebase deploy --only firestore:rules,firestore:indexes --project "$PROJECT" ) \
    && ok "Firestore rules + indexes deployed"
fi

# ---------------------------------------------------------------------------
bold "FLOWZAA SETUP SUMMARY  — copy this and send it back"
echo   "  Project        : $PROJECT"
echo   "  Maps API key   : ${MAPS_KEY:-<none>}"
echo   "  Customer app id : $(firebase apps:list ANDROID --project "$PROJECT" 2>/dev/null | grep "$CUSTOMER_PKG" | awk -F'│' '{print $3}' | tr -d ' ')"
echo   "  Captain app id  : $(firebase apps:list ANDROID --project "$PROJECT" 2>/dev/null | grep "$CAPTAIN_PKG" | awk -F'│' '{print $3}' | tr -d ' ')"
echo   "  google-services.json saved under apps/customer and apps/captain."
bold "Done."
