# 📱 Termux Android Build System (Java + C/C++ NDK)

[![Platform](https://shields.io)](https://termux.dev)
[![Architecture](https://shields.io)](#)
[![License](https://shields.io)](#)

A lightweight, standalone **Android build pipeline configured to run entirely inside Termux** on Android devices. It compiles mixed Java and Native C/C++ (NDK) projects directly into signed APKs without requiring Android Studio or a heavy Gradle installation.

---

## ✨ Features

- **Local Compilation** – Build functional Android packages entirely on your smartphone via Termux.
- **Java & Native Support** – Compiles Java source files alongside native C/C++ code (`arm64-v8a` target).
- **Automated Tooling** – Includes a setup script that automatically fetches the Android platform SDK and installs necessary packages.
- **Self-contained Keystore** – Generates its own release keystore if one does not exist.
- **Root Deployment** – Direct commands to install or uninstall built APKs on rooted testing devices.

## 🛠️ Tech Stack & Requirements

- **Shell Environment:** Termux
- **Android Platform API:** Version 33 (Android 13)
- **Compilers:** `javac` (Java 1.8), `aarch64-linux-android-clang++` (NDK)
- **Android CLI Build Tools:** `aapt2`, `dx`, `apksigner`

---

## 🚀 Getting Started

Follow these steps to set up your Termux environment and compile the sample project.

### 1. Environment Setup

Run the included setup script. This script updates your package repositories, installs essential command-line tools (`aapt2`, `apksigner`, `dx`, `zip`, `ndk-multilib`), and pulls the specific `android.jar` platform dependency directly from Google's repositories.

```bash
chmod +x setup.sh
./setup.sh
```

### 2. Compiling the Application

To execute the entire pipeline (resource compilation, Java compilation, DEX transformation, native library building, packaging, and code-signing), simply run:

```bash
make
```
Upon a successful run, your signed installer will be generated at `build/apk/app.apk`.

---

## 💡 Build Automation Controls (`Makefile`)

The project uses a structured `Makefile` workflow to segment individual compilation checkpoints. 

### Available Commands

| Command | Description |
| :--- | :--- |
| `make` | Orchestrates a **full compilation loop** and signs the generated APK. |
| `make install` | Deploys the signed package onto the host machine **(Requires Root)**. |
| `make uninstall` | Removes the deployed package (`com.example.myfirstapp`) from the device **(Requires Root)**. |
| `make clean` | Wipes the temporary scratchpad and resets the `build/` workspace directory. |
| `make key-gen` | Manually triggers the automated creation of the `my-release-key.jks` file. |
| `make rmbak` | Purges `.bak` backup files from the workspace tree. |
| `make help` | Prints the internal build help menu checklist. |

---

## 📁 Repository Structure

```text
.
├── AndroidManifest.xml      # Core app manifest file
├── Makefile                # Complete build automation configurations
├── res/                    # Layout configurations and string resources
│   ├── layout/activity_main.xml
│   └── values/strings.xml
├── setup.sh                # Dependency installation & environment setup script
├── src/
│   ├── com/example/myfirstapp/MainActivity.java  # Main Java Controller
│   └── jni/native.cpp                             # Native C/C++ engine
└── build/                  # Generated binary artifacts workspace (Ignored on clean)
```

---

## 🔒 Security Notice

The configuration file contains a default placeholder certificate credential signing block:
- **Keystore Pass:** `learningkey`
- **Key Alias:** `androidapk`

For public distribution applications, modify the identity attributes inside the `Makefile` prior to running `make key-gen` to secure your application identity footprint.