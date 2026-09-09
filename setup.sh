#!/bin/bash
# ============================================================================
#  Termux Environment Setup for Android App Development
#  Installs build tools, Android SDK platform, and NDK compiler
#  Keystore is generated automatically by the Makefile
# ============================================================================

set -e

echo "=== Installing build tools and NDK ==="
pkg install -y aapt2 apksigner dx zip ndk-multilib

echo ""
echo "=== Downloading Android SDK platform (android.jar) ==="
PLATFORM_ZIP="$HOME/platform-33.zip"
ANDROID_JAR_DIR="$HOME/android-sdk"
mkdir -p "$ANDROID_JAR_DIR"

if [ ! -f "$ANDROID_JAR_DIR/android.jar" ]; then
    curl -L -o "$PLATFORM_ZIP" \
        "https://dl.google.com/android/repository/platform-33_r02.zip"
    unzip -j "$PLATFORM_ZIP" "android-13/android.jar" -d "$ANDROID_JAR_DIR/"
    rm -f "$PLATFORM_ZIP"
    echo "   android.jar saved to $ANDROID_JAR_DIR/android.jar"
else
    echo "   android.jar already exists, skipping download"
fi

echo ""
echo "=== Verifying NDK compiler ==="
if command -v aarch64-linux-android-clang++ &> /dev/null; then
    echo "   NDK compiler found: aarch64-linux-android-clang++"
else
    echo "   Warning: aarch64-linux-android-clang++ not found. Make sure ndk-multilib is installed."
fi

echo ""
echo "=== Setup complete ==="
echo "You can now build the APK with: make"
echo "The Makefile will automatically generate the keystore if missing."
