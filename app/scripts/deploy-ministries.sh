#!/usr/bin/env bash
# Deploy Kharis App (com.kharis.church) to the Kharis Ministries team (Z9TTRH45X3)
# using an INDIVIDUAL App Store Connect API key (App Manager: ayoinc@gmail.com).
#
# Individual keys have NO issuer id, so xcodebuild cloud signing is unavailable.
# Instead: create a distribution cert + App Store profile via the ASC API,
# export with manual signing, then upload (altool; Transporter as fallback).
#
# One-time setup:
#   Download AuthKey_<KEYID>.p8 into ~/.appstoreconnect/private_keys/
#   export MIN_KEY_ID=<KEYID>
#
# Usage: scripts/deploy-ministries.sh [build_number]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

: "${MIN_KEY_ID:?Set MIN_KEY_ID to the individual API key id}"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${MIN_KEY_ID}.p8"
[[ -f "$KEY_PATH" ]] || { echo "ERROR: $KEY_PATH not found"; exit 1; }

TEAM_ID="Z9TTRH45X3"
BUNDLE_ID="com.kharis.church"
BUILD_NUMBER="${1:-$(date +%s)}"
WORK="/tmp/kharis-ministries-deploy"; mkdir -p "$WORK"

jwt() { # individual-key JWT: sub=user, no issuer
  python3 - "$MIN_KEY_ID" "$KEY_PATH" <<'PY'
import sys, json, time, base64
from subprocess import run
kid, keyfile = sys.argv[1], sys.argv[2]
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b'=')
header = b64(json.dumps({"alg":"ES256","kid":kid,"typ":"JWT"}).encode())
now = int(time.time())
payload = b64(json.dumps({"sub":"user","aud":"appstoreconnect-v1","iat":now,"exp":now+1100}).encode())
signing = header + b"." + payload
import tempfile, os
with tempfile.NamedTemporaryFile(delete=False) as f: f.write(signing); tmp=f.name
sig_der = run(["openssl","dgst","-sha256","-sign",keyfile,tmp],capture_output=True,check=True).stdout
os.unlink(tmp)
# DER ecdsa -> raw r||s
i=2; assert sig_der[0]==0x30
def read_int(b,i):
    assert b[i]==0x02; l=b[i+1]; v=b[i+2:i+2+l]; return v.lstrip(b'\x00').rjust(32,b'\x00'), i+2+l
r,i = read_int(sig_der,i); s,i = read_int(sig_der,i)
print((signing + b"." + b64(r+s)).decode())
PY
}

api() { # api GET/POST helper against official host
  local method="$1" path="$2" body="${3:-}"
  local tok; tok="$(jwt)"
  if [[ "$method" == GET ]]; then
    curl -sf -H "Authorization: Bearer $tok" "https://api.appstoreconnect.apple.com$path"
  else
    curl -sf -X "$method" -H "Authorization: Bearer $tok" -H "Content-Type: application/json" \
      -d "$body" "https://api.appstoreconnect.apple.com$path"
  fi
}

echo "==> 0. Sanity: key can see the Ministries app"
api GET "/v1/apps?filter[bundleId]=$BUNDLE_ID" | python3 -c "import sys,json;d=json.load(sys.stdin)['data'];print('   app:',d[0]['id'],d[0]['attributes']['name']) if d else (_ for _ in ()).throw(SystemExit('ERROR: key cannot see $BUNDLE_ID'))"

echo "==> 1. Distribution certificate (reuse if present, else create)"
CERT_JSON="$(api GET "/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=10")"
CERT_ID="$(echo "$CERT_JSON" | python3 -c "import sys,json;d=[c for c in json.load(sys.stdin)['data']];print(d[0]['id'] if d else '')")"
P12_KEY="$WORK/dist_private.key"
if [[ -z "$CERT_ID" || ! -f "$P12_KEY" ]]; then
  openssl req -new -newkey rsa:2048 -nodes -keyout "$P12_KEY" \
    -out "$WORK/dist.csr" -subj "/CN=Kharis Ministries Distribution/O=$TEAM_ID" 2>/dev/null
  CSR_CONTENT="$(sed '/-----/d' "$WORK/dist.csr" | tr -d '\n')"
  BODY="$(python3 -c "import json,sys;print(json.dumps({'data':{'type':'certificates','attributes':{'certificateType':'DISTRIBUTION','csrContent':sys.argv[1]}}}))" "$CSR_CONTENT")"
  CERT_JSON="$(api POST "/v1/certificates" "$BODY")"
  CERT_ID="$(echo "$CERT_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['id'])")"
fi
echo "   cert: $CERT_ID"
echo "$CERT_JSON" | python3 -c "
import sys,json,base64
d=json.load(sys.stdin)['data']
d=d[0] if isinstance(d,list) else d
open('$WORK/dist.cer','wb').write(base64.b64decode(d['attributes']['certificateContent']))"
security import "$WORK/dist.cer" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true
[[ -f "$P12_KEY" ]] && security import "$P12_KEY" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true

echo "==> 2. App Store provisioning profile"
BID="$(api GET "/v1/bundleIds?filter[identifier]=$BUNDLE_ID" | python3 -c "import sys,json;print(json.load(sys.stdin)['data'][0]['id'])")"
PROF_BODY="$(python3 -c "import json;print(json.dumps({'data':{'type':'profiles','attributes':{'name':'Kharis church AppStore $BUILD_NUMBER','profileType':'IOS_APP_STORE'},'relationships':{'bundleId':{'data':{'type':'bundleIds','id':'$BID'}},'certificates':{'data':[{'type':'certificates','id':'$CERT_ID'}]}}}}))")"
PROFILE_JSON="$(api POST "/v1/profiles" "$PROF_BODY")"
echo "$PROFILE_JSON" | python3 -c "
import sys,json,base64
d=json.load(sys.stdin)['data']
open('$WORK/appstore.mobileprovision','wb').write(base64.b64decode(d['attributes']['profileContent']))
print('   profile:',d['id'],d['attributes']['uuid'])"
PROF_UUID="$(security cms -D -i "$WORK/appstore.mobileprovision" 2>/dev/null | plutil -extract UUID raw -o - -)"
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp "$WORK/appstore.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/"$PROF_UUID".mobileprovision

echo "==> 3. Archive (flutter) build $BUILD_NUMBER"
ARCHIVE="build/ios/archive/Runner.xcarchive"
if [[ "${SKIP_ARCHIVE:-0}" == 1 && -d "$ARCHIVE" ]]; then
  echo "   reusing pre-built archive (build $(plutil -extract ApplicationProperties.CFBundleVersion raw -o - "$ARCHIVE/Info.plist" 2>/dev/null))"
else
rm -rf "$ARCHIVE"
flutter build ipa --release --dart-define-from-file=env.json --build-number="$BUILD_NUMBER" || true
fi
[[ -d "$ARCHIVE" ]] || { echo "ERROR: archive not produced"; exit 1; }

echo "==> 4. Export signed IPA (manual signing)"
SIGN_ID="$(security find-identity -v -p codesigning | grep -m1 'Distribution' | sed 's/.*"\(.*\)"/\1/')"
EXPORT_PLIST="$WORK/export.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$SIGN_ID</string>
  <key>provisioningProfiles</key><dict>
    <key>$BUNDLE_ID</key><string>$PROF_UUID</string>
  </dict>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
rm -rf "$WORK/export"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" -exportPath "$WORK/export"
IPA="$(ls "$WORK"/export/*.ipa | head -1)"
echo "   IPA: $IPA"

echo "==> 5. Upload (altool with individual key)"
if xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$MIN_KEY_ID" --apiIssuer "user" 2>"$WORK/altool.err"; then
  echo "UPLOAD SUCCEEDED"
else
  echo "altool failed (individual keys sometimes need Transporter):"
  tail -5 "$WORK/altool.err"
  echo "IPA ready for Transporter: $IPA"
  open -a Transporter "$IPA" 2>/dev/null || true
fi
