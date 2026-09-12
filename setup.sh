#!/bin/bash
# ============================================================================
#  Environment Setup for Android App Development
#  Auto-detects Termux vs Linux Mint / Ubuntu / Debian
#  JDK 21 primary, JDK 17 fallback
#  Android SDK: platform 33 (Android 13) — supports Android 12 (API 31)
# ============================================================================

set -e

# ----------------------------------------------------------------------------
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then
    IS_TERMUX=true
    echo "=== Detected Environment: Termux (Android) ==="
else
    IS_TERMUX=false
    echo "=== Detected Environment: Linux (Ubuntu / Mint / Debian) ==="
fi

# ============================================================================
echo ""
echo "=== Installing base build tools ==="

if [ "$IS_TERMUX" = true ]; then
    pkg update -y
    pkg install -y aapt2 apksigner dx zip unzip curl wget make clang \
        openjdk-21 ndk-multilib \
        || pkg install -y aapt2 apksigner dx zip unzip curl wget make clang \
            openjdk-17 ndk-multilib
    pkg install -y zipalign 2>/dev/null || \
        echo "   Note: zipalign not available (optional)."
else
    sudo apt-get update
    sudo apt-get install -y openjdk-21-jdk adb clang make zip unzip curl wget file \
        || sudo apt-get install -y openjdk-17-jdk adb clang make zip unzip curl wget file

    # dx (needed because d8 crashes on JDK 21)
    if ! command -v dx >/dev/null 2>&1; then
        sudo apt-get install -y dalvik-exchange || true
        if [ -f /usr/bin/dalvik-exchange ] && [ ! -f /usr/bin/dx ]; then
            sudo ln -sf /usr/bin/dalvik-exchange /usr/bin/dx
        fi
    fi
fi

# ============================================================================
if [ "$IS_TERMUX" = false ]; then
    JDK21_HOME=""
    for cand in \
        "/usr/lib/jvm/java-21-openjdk-amd64" \
        "/usr/lib/jvm/java-21-openjdk"
    do
        if [ -d "$cand" ]; then JDK21_HOME="$cand"; break; fi
    done

    if [ -n "$JDK21_HOME" ]; then
        if ! grep -q "java-21-openjdk" "$HOME/.bashrc" 2>/dev/null; then
            {
                echo ""
                echo "# Java 21 (added by setup.sh)"
                echo "export JAVA_HOME=$JDK21_HOME"
                echo "export PATH=\$JAVA_HOME/bin:\$PATH"
            } >> "$HOME/.bashrc"
        fi
        export JAVA_HOME="$JDK21_HOME"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
fi

# ============================================================================
#  Android SDK — android.jar
#  Uses API 33 (Android 13). minSdk=21 → supports Android 12 (API 31).
#  NOTE: platform-34_r02.zip URL no longer exists on Google's server.
#        platform-33_r02.zip is verified working.
# ============================================================================
echo ""
echo "=== Setting up Android SDK (android.jar) ==="
ANDROID_SDK_DIR="$HOME/android-sdk"
mkdir -p "$ANDROID_SDK_DIR"

# Prefer an already-correct system android.jar
SYS_JAR=""
for cand in \
    /usr/lib/android-sdk/platforms/android-34/android.jar \
    /usr/lib/android-sdk/platforms/android-33/android.jar \
    /usr/lib/android-sdk/platforms/android-31/android.jar
do
    if [ -f "$cand" ]; then SYS_JAR="$cand"; break; fi
done

if [ -n "$SYS_JAR" ]; then
    ln -sf "$SYS_JAR" "$ANDROID_SDK_DIR/android.jar"
    echo "   Using system android.jar -> $SYS_JAR"
elif [ ! -f "$ANDROID_SDK_DIR/android.jar" ]; then
    PLATFORM_ZIP="/tmp/platform-33.zip"
    echo "   Downloading android.jar (API 33) from Google..."
    curl -L -o "$PLATFORM_ZIP" \
        "https://dl.google.com/android/repository/platform-33_r02.zip"

    # Verify the download is a real zip (>1 MB)
    SIZE=$(stat -c%s "$PLATFORM_ZIP" 2>/dev/null || echo 0)
    if [ "$SIZE" -lt 1000000 ]; then
        echo "   Error: downloaded file is too small ($SIZE bytes) — likely an error page."
        echo "   URL may be unavailable. Please check your internet connection."
        rm -f "$PLATFORM_ZIP"
        exit 1
    fi

    unzip -j "$PLATFORM_ZIP" "android-13/android.jar" -d "$ANDROID_SDK_DIR/"
    rm -f "$PLATFORM_ZIP"
    echo "   android.jar saved to $ANDROID_SDK_DIR/android.jar"
else
    echo "   android.jar already exists, skipping download"
fi

# ============================================================================
if [ "$IS_TERMUX" = true ]; then
    echo ""
    echo "=== Termux: using system tools from \$PREFIX/bin ==="
    for tool in aapt2 dx d8 apksigner zipalign; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   OK: $tool -> $(command -v $tool)"
        else
            echo "   OPTIONAL-MISSING: $tool"
        fi
    done
else
    echo ""
    echo "=== Installing Android build-tools r34 (Linux x86_64) ==="
    BT_VERSION="34.0.0"
    BT_PARENT="$ANDROID_SDK_DIR/build-tools"
    BT_DIR="$BT_PARENT/$BT_VERSION"
    BT_ZIP="/tmp/build-tools-r34.zip"

    if [ ! -x "$BT_DIR/aapt2" ]; then
        echo "   Downloading build-tools r34..."
        wget -q --show-progress \
            "https://dl.google.com/android/repository/build-tools_r34-linux.zip" \
            -O "$BT_ZIP"

        mkdir -p "$BT_PARENT"
        TMP_EXTRACT="/tmp/bt_extract_$$"
        mkdir -p "$TMP_EXTRACT"
        unzip -q "$BT_ZIP" -d "$TMP_EXTRACT"

        EXTRACTED=$(find "$TMP_EXTRACT" -maxdepth 1 -mindepth 1 -type d | head -n1)
        rm -rf "$BT_DIR"
        mv "$EXTRACTED" "$BT_DIR"
        rm -rf "$TMP_EXTRACT" "$BT_ZIP"
    fi

    if ! grep -q "android-sdk/build-tools" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# Android SDK build-tools (added by setup.sh)"
            echo "export PATH=\$PATH:$BT_DIR"
        } >> "$HOME/.bashrc"
    fi
    export PATH="$PATH:$BT_DIR"

    for tool in aapt2 d8 zipalign apksigner; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   OK: $tool -> $(command -v $tool)"
        fi
    done
fi

# ============================================================================
echo ""
echo "=== Verifying NDK / C++ compiler ==="
if [ "$IS_TERMUX" = true ]; then
    if command -v aarch64-linux-android-clang++ &> /dev/null; then
        echo "   NDK compiler found: aarch64-linux-android-clang++"
    elif command -v clang++ &> /dev/null; then
        echo "   C++ compiler found: clang++ (fallback)"
    else
        echo "   Warning: Run: pkg install ndk-multilib clang"
    fi
else
    NDK_VERSION="r27c"
    NDK_DIR="$HOME/android-ndk-$NDK_VERSION"
    NDK_ZIP="/tmp/android-ndk-$NDK_VERSION-linux.zip"

    if [ ! -d "$NDK_DIR" ]; then
        echo "   Downloading NDK $NDK_VERSION..."
        wget -q --show-progress \
            "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" \
            -O "$NDK_ZIP"
        unzip -q "$NDK_ZIP" -d "$HOME"
        rm -f "$NDK_ZIP"
    fi

    NDK_BIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"
    if ! grep -q "ANDROID_NDK_HOME" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# Android NDK (added by setup.sh)"
            echo "export ANDROID_NDK_HOME=$NDK_DIR"
            echo "export PATH=\$PATH:$NDK_BIN"
        } >> "$HOME/.bashrc"
    fi
    export ANDROID_NDK_HOME="$NDK_DIR"
    export PATH="$PATH:$NDK_BIN"

    if [ -x "$NDK_BIN/aarch64-linux-android21-clang++" ]; then
        echo "   NDK compiler verified."
    else
        echo "   Error: NDK cross-compiler not found."
        exit 1
    fi
fi

echo ""
echo "=== Setup complete ==="
echo "NOTE: Run:  source ~/.bashrc"