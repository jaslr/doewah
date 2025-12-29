#!/bin/bash
# Publish a new APK release to the update server
# Usage: ./scripts/publish-release.sh [debug|release]

set -e

BUILD_TYPE="${1:-debug}"
source .env

# Get version from pubspec.yaml
VERSION=$(grep 'version:' app/pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
BUILD_NUMBER=$(grep 'version:' app/pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)

APK_NAME="doewah-${VERSION}-${BUILD_TYPE}.apk"
LOCAL_APK="app/build/app/outputs/apk/${BUILD_TYPE}/${APK_NAME}"

if [ ! -f "$LOCAL_APK" ]; then
  echo "APK not found: $LOCAL_APK"
  echo "Build first with: flutter build apk --${BUILD_TYPE}"
  exit 1
fi

echo "Publishing ${APK_NAME} to droplet..."

# Create releases directory on droplet
ssh -i ${DROPLET_SSH_KEY} root@${DROPLET_IP} "mkdir -p /root/doewah/releases"

# Copy APK to droplet
scp -i ${DROPLET_SSH_KEY} "$LOCAL_APK" root@${DROPLET_IP}:/root/doewah/releases/

# Update version.json on droplet
ssh -i ${DROPLET_SSH_KEY} root@${DROPLET_IP} "cat > /root/doewah/releases/version.json << EOF
{
  \"version\": \"${VERSION}\",
  \"buildNumber\": ${BUILD_NUMBER},
  \"apkFile\": \"${APK_NAME}\",
  \"releaseDate\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"changelog\": \"Latest release\"
}
EOF"

echo "Published ${APK_NAME}"
echo "Version: ${VERSION}+${BUILD_NUMBER}"
echo ""
echo "Update server URL: http://${DROPLET_IP}:8406/version"
