# 📱 Linux & Android (Termux) APK Build System
## Build APKs on Linux Mint, Ubuntu, Debian & Termux — No Android Studio Required

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Termux-green.svg)](https://termux.dev)
[![Language](https://img.shields.io/badge/language-Java%20%2B%20C%2B%2B-orange.svg)](#)
[![Status](https://img.shields.io/badge/status-Active-brightgreen.svg)](#)

A lightweight, self-contained **Android development environment** that runs on both **Linux PCs (Linux Mint, Ubuntu, Debian)** and directly inside **Termux on Android**. Compile mixed Java and Native C/C++ projects directly into production-ready, aligned, and signed APKs using only standard CLI tools.

---

## ✨ Key Features

- **🚀 Dual Platform** – Works seamlessly on Linux PC (Mint/Ubuntu/Debian via `apt`) and Android (Termux via `pkg`)
- **☕ Java + Native C/C++ Support** – Mix Java (OpenJDK 21/17) and NDK C++ in one project
- **🔧 JNI Integration** – Call native C++ functions directly from Java
- **⚙️ Full Automation** – Single `make` command builds the entire APK pipeline
- **📐 4-Byte ZipAlign** – Android standard alignment for fast app loading and verification
- **🔐 Self-Signed Certificates** – Automatic keystore generation with v1, v2, and v3 signature schemes
- **📲 Smart Install** – `make install` uses ADB on PC (with device check) or Root (`su`) inside Termux
- **🎯 Minimal Dependencies** – No Gradle, no Android Studio required

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| **Language** | Java 1.8 + C/C++ (NDK/JNI) |
| **JDK** | OpenJDK 21 (with OpenJDK 17 fallback) |
| **Build System** | GNU Make |
| **Resource Compiler** | AAPT2 |
| **Java Compiler** | javac |
| **DEX Compiler** | d8 (modern) / dx (fallback) |
| **Native Compiler** | aarch64-linux-android-clang++ (Termux/NDK) / clang++ (PC) |
| **Alignment Tool** | zipalign (4-byte alignment) |
| **Signing Tool** | apksigner (v1, v2, v3 signing) |
| **Target API** | Android 13 (API 33) / API 23+ compatible |
| **Deployment** | ADB (PC) / su pm (Termux) |

---

## 📋 Prerequisites

- **On PC:** Linux Mint, Ubuntu, or Debian
- **On Phone:** Android device with [Termux](https://termux.dev)
- **Internet connection** (for one-time setup)
- **~500MB free storage** (for Android SDK platform + build tools)

---

## 🚀 Quick Start

### Step 1: Environment Setup

Run the setup script. It automatically detects whether you are in **Termux** or on **PC (apt)**:

```bash
chmod +x setup.sh
./setup.sh
```

**What it does:**
- ✅ **Termux:** Installs `aapt2`, `apksigner`, `dx`, `zip`, `ndk-multilib`, and `openjdk-21` via `pkg` (no `sudo`)
- ✅ **PC (apt):** Installs `openjdk-21-jdk`, `adb`, `clang`, `make`, `zip`, `google-android-build-tools`, `zipalign`, and `apksigner` via `apt`
- ✅ Sets up `android.jar` (downloads API 33 platform or links system SDK)
- ✅ Verifies C++/NDK compiler availability

### Step 2: Build Your App

Build the entire project with a single command:

```bash
make
```

**Output:** `build/apk/app.apk` (aligned, signed, and ready to install)

### Step 3: Install on Device (Optional)

Deploy the APK directly to your device:

```bash
make install
```

- **On PC:** Automatically checks for connected Android devices via ADB and installs the APK. If no device is connected, it alerts you.
- **On Termux:** Installs directly on rooted devices using `su -c pm install`.

---

## 📁 Project Structure

```
build-apk-in-termux/
│
├── 📄 AndroidManifest.xml         # App configuration & permissions
├── 📋 Makefile                    # Build automation (GNU Make)
├── 📝 setup.sh                    # Environment setup script (Termux & Linux apt)
├── 🔑 my-release-key.jks          # Signing certificate (auto-generated if missing)
├── README.md                      # Project documentation
├── LICENSE                        # MIT License
│
├── 📁 src/                        # Source code
│   ├── com/example/myfirstapp/
│   │   └── MainActivity.java      # Main Activity (Java entry point)
│   └── jni/
│       └── native.cpp             # Native C++ code (JNI)
│
├── 📁 res/                        # Android resources
│   ├── layout/
│   │   └── activity_main.xml      # UI layout
│   └── values/
│       └── strings.xml            # String constants
│
└── 📁 build/                      # Generated artifacts (auto-created)
    ├── classes.dex
    ├── lib/arm64-v8a/libnative.so
    ├── compiled_res/
    └── apk/app.apk
```

---

## 🔄 Build Pipeline Explained

```
┌──────────────────────────────────────────────────────────────────┐
│                 COMPLETE BUILD WORKFLOW (make)                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. RESOURCE COMPILATION                                        │
│     res/ (XML) ───────────────[aapt2 compile]──> compiled_res/  │
│                                                                  │
│  2. RESOURCE LINKING & R.java GENERATION                        │
│     compiled_res/ + android.jar ─[aapt2 link]──> gen/R.java      │
│                                                                  │
│  3. JAVA COMPILATION                                            │
│     src/ + gen/R.java ─────────────[javac]─────> build/obj/     │
│                                                                  │
│  4. NATIVE LIBRARY COMPILATION (Optional JNI)                   │
│     src/jni/ ───────────────[clang++]──────────> libnative.so   │
│                                                                  │
│  5. DEX CONVERSION                                              │
│     build/obj/ ───────────────[d8 / dx]────────> classes.dex    │
│                                                                  │
│  6. APK PACKAGING & ALIGNMENT                                   │
│     classes.dex + *.so + res ────[zip]─────────> unaligned.apk  │
│     unaligned.apk ─────────[zipalign 4-byte]───> aligned.apk    │
│                                                                  │
│  7. APK SIGNING (v1 + v2 + v3)                                  │
│     aligned.apk ─────────────[apksigner]───────> apk/app.apk    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🎮 Available Make Commands

| Target | Description |
|--------|-------------|
| `make` | Full build (DEX + Native Lib + APK packaging & signing) |
| `make lib` | Build native C++ library only |
| `make dex` | Compile Java and resources into `classes.dex` |
| `make apk` | Package, align with `zipalign`, and sign with `apksigner` |
| `make clean` | Remove all build artifacts |
| `make install` | Install APK on device via ADB or `su` |
| `make uninstall`| Uninstall app from device |
| `make key-gen` | Generate release keystore |
| `make help` | Show help menu and auto-detected tool paths |

---

## 💻 Example: Modifying the App

### Change App Name & Package

Edit `AndroidManifest.xml`:
```xml
<manifest package="com.yourcompany.yourapp">
    <application android:label="Your App Name">
        ...
    </application>
</manifest>
```

Update Makefile variables:
```makefile
PKG_NAME := com.yourcompany.yourapp
```

### Add Java Code

Create a new Java file in `src/com/example/myfirstapp/`:
```java
public class Utils {
    public static String getGreeting() {
        return "Hello from Java!";
    }
}
```

Then call it from `MainActivity.java`:
```java
output.setText(Utils.getGreeting());
```

### Add Native C++ Code

Extend `src/jni/native.cpp`:
```c++
extern "C" JNIEXPORT jint JNICALL
Java_com_example_myfirstapp_MainActivity_add(JNIEnv* env, jobject, jint a, jint b) {
    return a + b;
}
```

Add method to `MainActivity.java`:
```java
public native int add(int a, int b);
```

Call from Java:
```java
int result = add(5, 3); // Result: 8
```

---

## 🔐 Security & Key Management

### Default Keystore Credentials
```
File: my-release-key.jks
Keystore Password: learningkey
Key Alias: androidapk
Key Password: learningkey
Validity: 10,000 days
```

### For Production/Distribution

**Before publishing on Play Store or distributing publicly:**

1. **Backup your signing key:**
   ```bash
   cp my-release-key.jks my-release-key.backup
   ```

2. **Create a new secure keystore:**
   ```bash
   keytool -genkey -v -keystore my-secure-key.jks \
       -alias production \
       -keyalg RSA -keysize 4096 -validity 10000 \
       -storepass YOUR_SECURE_PASSWORD \
       -keypass YOUR_SECURE_PASSWORD
   ```

3. **Update Makefile:**
   ```makefile
   KEYSTORE := my-secure-key.jks
   KEY_ALIAS := production
   KEY_PASS := YOUR_SECURE_PASSWORD
   ```

⚠️ **Never** commit sensitive keystores to version control!

---

## 🐛 Troubleshooting

### Issue: `android.jar not found`

**Solution:**
```bash
./setup.sh
```
Then verify the path in Makefile:
```makefile
ANDROID_JAR := $(HOME)/android-sdk/android.jar
```

### Issue: `C++ compiler not found`

**Solution:**
- **On Termux:**
  ```bash
  pkg install -y ndk-multilib
  ```
- **On Linux PC (Mint / Ubuntu / Debian):**
  ```bash
  sudo apt install -y clang
  ```

### Issue: Build fails with `No C++ source files found`

**Solution:** Ensure `src/jni/` directory exists with `.cpp` or `.c` files:
```bash
mkdir -p src/jni
# Copy or create your C++ file
```

### Issue: APK signing fails

**Solution:** Regenerate keystore:
```bash
rm my-release-key.jks
make key-gen
```

### Issue: `make install` fails or says no device found

**Solution:**
- **On PC:** Make sure your phone is connected via USB with **USB Debugging** enabled, or an Android emulator is running. Run `adb devices` in your terminal to verify.
- **On Termux:** The device must be rooted (`su`) to install directly from the terminal. On non-rooted devices, you can install the generated APK manually from `build/apk/app.apk`.

---

## 📊 Project Statistics

- **Build Time:** ~10-15 seconds (first build)
- **APK Size:** ~50-100 KB (minimal sample app)
- **Storage Required:** ~500 MB (Android SDK + tools)
- **Memory Usage:** ~200 MB during compilation

---

## 🎯 Customization Guide

### Modify App Colors & Branding

Edit `res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">My Custom App</string>
    <string name="welcome_text">Welcome to My App</string>
</resources>
```

Edit `res/layout/activity_main.xml` for UI changes.

### Add Permissions

Update `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Target Different Android Versions

Modify `AndroidManifest.xml`:
```xml
<uses-sdk android:minSdkVersion="21" android:targetSdkVersion="34" />
```

And update Makefile:
```makefile
ANDROID_JAR := $(HOME)/android-sdk/android-34.jar
```

---

## 📚 Learning Resources

- [Android Developer Documentation](https://developer.android.com)
- [JNI Documentation](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/)
- [NDK Build Guide](https://developer.android.com/ndk/guides)
- [Linux Documentation](https://termux.dev)
- [AAPT2 Reference](https://developer.android.com/studio/command-line/aapt2)

---

## 🤝 Contributing

Found a bug or want to improve this project?

1. **Fork** this repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

---

## 📝 License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 👤 Author

**Mahadi Hasan**
- GitHub: [@mahadihasan9](https://github.com/mahadihasan9)
- Email: Contact via GitHub

---

## 🙋 FAQ

**Q: Which operating systems are supported?**  
A: Linux Mint, Ubuntu, Debian, and Android (Termux). All dependencies are handled automatically via `setup.sh`. Windows is supported via WSL2.

**Q: Is this production-ready?**  
A: Yes! The APK output is fully signed and can be distributed. Just use your own secure keystore credentials.

**Q: Can I add more native libraries?**  
A: Yes. Add `.c` or `.cpp` files to `src/jni/` and they'll be compiled automatically.

**Q: What's the maximum APK size?**  
A: No practical limit with this system. Large apps (100+ MB) may take longer to compile.

**Q: Can I use third-party libraries (Maven/Gradle)?**  
A: This system doesn't use Gradle. You'd need to manually download JARs and add them to the classpath in Makefile.

**Q: How do I debug the app?**  
A: You can add Log statements in Java/C++ code and view them with `logcat`.

---

## 🚀 What's Next?

- [x] Basic Java + NDK build system
- [ ] Gradle/Maven integration
- [ ] Debug symbol support
- [ ] Multi-architecture builds (arm, x86)
- [ ] Automated testing framework

---

## 💡 Tips & Best Practices

1. **Always backup your keystore** before regenerating
2. **Clean build frequently** to avoid stale artifacts: `make clean`
3. **Test on multiple devices** for compatibility
4. **Use meaningful package names** (e.g., `com.company.appname`)
5. **Keep native code in `src/jni/`** for organization
6. **Version your keystores** in a secure location
7. **Comment your build targets** in Makefile for future reference

---

## ⭐ Show Your Support

If this project helped you build Android apps on your phone, please consider:
- ⭐ **Starring** this repository
- 🐛 **Reporting issues** you encounter
- 💬 **Sharing feedback** and suggestions
- 🔄 **Contributing** improvements

---

**Happy Building! 🎉**

*Built with ❤️ for the Linux community*
