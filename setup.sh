#!/bin/bash
# ============================================================================
#  Linux Environment Setup for Android App Development
#  Replaced Termux pkg with apt-get for Linux Mint / Ubuntu / Debian
# ============================================================================

set -e

echo "=== Installing build tools and compiler ==="
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk clang make zip unzip curl \
    google-android-build-tools-34.0.0-installer dalvik-exchange zipalign apksigner libandroid-23-java || true

# Setup dalvik-exchange alias to dx if it doesn't exist
if [ ! -f /usr/bin/dx ] && [ -f /usr/bin/dalvik-exchange ]; then
    sudo ln -s /usr/bin/dalvik-exchange /usr/bin/dx
fi

echo ""
echo "=== Setting up Android SDK platform (android.jar) ==="
ANDROID_JAR_DIR="$HOME/android-sdk"
mkdir -p "$ANDROID_JAR_DIR"

if [ ! -f "$ANDROID_JAR_DIR/android.jar" ]; then
    if [ -f /usr/lib/android-sdk/platforms/android-23/android.jar ]; then
        ln -sf /usr/lib/android-sdk/platforms/android-23/android.jar "$ANDROID_JAR_DIR/android.jar"
        echo "   Using system android.jar -> $ANDROID_JAR_DIR/android.jar"
    else
        PLATFORM_ZIP="/tmp/platform-33.zip"
        echo "   Downloading android.jar from Google repository..."
        curl -L -o "$PLATFORM_ZIP" "https://dl.google.com/android/repository/platform-33_r02.zip"
        unzip -j -q "$PLATFORM_ZIP" "android-13/android.jar" -d "$ANDROID_JAR_DIR/"
        rm -f "$PLATFORM_ZIP"
        echo "   android.jar saved to $ANDROID_JAR_DIR/android.jar"
    fi
else
    echo "   android.jar already exists, skipping"
fi

echo ""
echo "=== Verifying C++ compiler ==="
if command -v clang++ &> /dev/null; then
    echo "   Compiler found: $(which clang++)"
else
    echo "   Warning: clang++ not found. Please install clang."
fi

echo ""
echo "=== Setup complete ==="
echo "You can now build the APK with: make"
