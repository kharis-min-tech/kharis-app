#!/usr/bin/env bash
set -euo pipefail

# Uploads the signed release AAB to the Play Internal testing track.
#
# One-time prerequisite (Play Console ADMIN on the Kharis Church account):
#   Users and permissions -> Invite new users ->
#     play-publisher@kharis-app-47c49.iam.gserviceaccount.com
#   App permissions: Kharis Church (com.kharis.church)
#   Permissions: "Release to testing tracks" (+ "View app information")
#
# Caller needs: gcloud auth as a principal with serviceAccountTokenCreator
# on the SA (ayoinc@gmail.com already has this).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/.."
PKG="com.kharis.church"
SA="play-publisher@kharis-app-47c49.iam.gserviceaccount.com"
BUNDLE="${1:-$APP_DIR/build/app/outputs/bundle/release/app-release.aab}"
API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PKG"
UPLOAD="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PKG"

[[ -f "$BUNDLE" ]] || { echo "ERROR: bundle not found: $BUNDLE"; echo "Build it: (cd app && flutter build appbundle --release --dart-define-from-file=env.json)"; exit 1; }

echo "==> Minting Play API token (impersonating $SA)"
TOK=$(gcloud auth print-access-token \
  --impersonate-service-account="$SA" \
  --scopes=https://www.googleapis.com/auth/androidpublisher)

echo "==> Creating edit"
EDIT=$(curl -sf -X POST -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" \
  -d '{}' "$API/edits" | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")
echo "    edit=$EDIT"

echo "==> Uploading $(du -h "$BUNDLE" | cut -f1) AAB (this can take a few minutes)"
VC=$(curl -sf -X POST -H "Authorization: Bearer $TOK" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$BUNDLE" \
  "$UPLOAD/edits/$EDIT/bundles?uploadType=media" \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['versionCode'])")
echo "    versionCode=$VC"

echo "==> Assigning versionCode $VC to the internal track"
curl -sf -X PUT -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" \
  -d "{\"releases\":[{\"versionCodes\":[\"$VC\"],\"status\":\"completed\"}]}" \
  "$API/edits/$EDIT/tracks/internal" >/dev/null

echo "==> Committing edit"
curl -sf -X POST -H "Authorization: Bearer $TOK" \
  "$API/edits/$EDIT:commit" >/dev/null

cat <<DONE

Internal testing release committed (versionCode $VC).
Next (Play Console, any user with release access):
  Testing -> Internal testing -> Testers tab -> add the volunteers'
  email list -> copy the opt-in link and share it.
DONE
