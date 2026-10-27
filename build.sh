#!/usr/bin/env bash
# Builds a signed release APK at build/JumpBox.apk.
# First run makes a signing key in ~/.android/. Keep that key: Android only installs an
# update over the old app when both are signed with the same key.
set -euo pipefail
cd "$(dirname "$0")"

export JAVA_HOME="${JAVA_HOME_17:-/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
KEYSTORE="${JUMPBOX_KEYSTORE:-$HOME/.android/jumpbox-release.keystore}"
PASSFILE="$KEYSTORE.pass"

if [ ! -f "$KEYSTORE" ]; then
	mkdir -p "$(dirname "$KEYSTORE")"
	openssl rand -hex 16 > "$PASSFILE"
	chmod 600 "$PASSFILE"
	"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KEYSTORE" -alias jumpbox \
		-keyalg RSA -keysize 2048 -validity 20000 \
		-storepass "$(cat "$PASSFILE")" -keypass "$(cat "$PASSFILE")" \
		-dname "CN=JumpBox" >/dev/null
	echo "Made signing key: $KEYSTORE"
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="jumpbox"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$PASSFILE")"

mkdir -p build
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release Android build/JumpBox.apk
ls -lh build/JumpBox.apk
