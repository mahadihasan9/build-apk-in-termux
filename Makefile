# ============================================================================
#  Android Application Build System
#  Makefile for Linux Mint / Ubuntu / Debian (apt) and Termux
#  Supports Java + NDK (C/C++) projects
# ============================================================================

# ----------------------------------------------------------------------------
#  Toolchain & Environment Auto-Detection
# ----------------------------------------------------------------------------
PROJECT_DIR  := $(shell pwd)
KEYSTORE     := my-release-key.jks
KEY_ALIAS    := androidapk
KEY_PASS     := learningkey
PKG_NAME     := com.example.myfirstapp
PKG_PATH     := com/example/myfirstapp

# Auto-detect ANDROID_JAR
ANDROID_JAR  ?= $(firstword \
	$(wildcard $(HOME)/android-sdk/android.jar) \
	$(wildcard /usr/lib/android-sdk/platforms/android-34/android.jar) \
	$(wildcard /usr/lib/android-sdk/platforms/android-33/android.jar) \
	$(wildcard /usr/lib/android-sdk/platforms/android-23/android.jar) \
	$(wildcard /usr/lib/android-sdk/platforms/android-*/android.jar) \
	$(wildcard $(ANDROID_HOME)/platforms/android-*/android.jar) \
	$(wildcard $(ANDROID_SDK_ROOT)/platforms/android-*/android.jar) \
)

# Detect DEX compiler (prefer modern d8, fallback to dx)
D8_BIN       := $(shell which d8 2>/dev/null)
DX_BIN       := $(shell which dx 2>/dev/null)

# Detect zipalign and apksigner
ZIPALIGN_BIN := $(shell which zipalign 2>/dev/null)
APKSIGNER    := $(shell which apksigner 2>/dev/null)
AAPT2_BIN    := $(shell which aapt2 2>/dev/null)

# Detect Java & JNI Headers
JAVA_DETECTED := $(shell dirname $$(dirname $$(readlink -f $$(which javac 2>/dev/null) 2>/dev/null) 2>/dev/null) 2>/dev/null)
JAVA_HOME     ?= $(JAVA_DETECTED)
JNI_INCLUDES  := $(if $(wildcard $(JAVA_HOME)/include),-I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux,)

# Auto-detect Android NDK
NDK_DETECTED  := $(firstword \
	$(wildcard $(ANDROID_NDK_HOME)) \
	$(wildcard $(NDK_HOME)) \
	$(wildcard /usr/lib/android-sdk/ndk/*) \
	$(wildcard $(HOME)/Android/Sdk/ndk/*) \
	$(wildcard $(HOME)/android-ndk-*) \
)
NDK_CLANG     := $(firstword $(wildcard $(NDK_DETECTED)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android*-clang++))

# ----------------------------------------------------------------------------
#  Build Directories
# ----------------------------------------------------------------------------
BUILD_DIR    := build
GEN_DIR      := $(BUILD_DIR)/gen
OBJ_DIR      := $(BUILD_DIR)/obj
APK_DIR      := $(BUILD_DIR)/apk
COMPILED_RES := $(BUILD_DIR)/compiled_res
LIB_DIR      := $(BUILD_DIR)/lib/arm64-v8a

# ----------------------------------------------------------------------------
#  Source Discovery
# ----------------------------------------------------------------------------
JAVA_SRCS    := $(shell find src -name "*.java" 2>/dev/null)
CPP_SRCS     := $(shell find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak" 2>/dev/null)
CPP_FIRST    := $(firstword $(CPP_SRCS))
LIB_NAME     := $(if $(CPP_FIRST),$(basename $(notdir $(CPP_FIRST))),native)
LIB_SO       := lib$(LIB_NAME).so
LIB_PATH     := $(LIB_DIR)/$(LIB_SO)

# ----------------------------------------------------------------------------
#  Colors for Output
# ----------------------------------------------------------------------------
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
MAGENTA:= \033[0;35m
CYAN   := \033[0;36m
RESET  := \033[0m
BOLD   := \033[1m

# ----------------------------------------------------------------------------
#  Targets
# ----------------------------------------------------------------------------
.PHONY: all help clean install uninstall setup-dirs check-env \
        compile-res link-res compile-java dex \
        key-gen generate-key rmbak lib apk sign

# ----------------------------------------------------------------------------
#  Default Target: Full Build (Java + Resources + DEX + Lib + APK)
# ----------------------------------------------------------------------------
all: check-env dex lib apk
	@echo ""
	@echo "$(GREEN)==========================================$(RESET)"
	@echo "$(GREEN)  BUILD SUCCESSFUL: $(APK_DIR)/app.apk$(RESET)"
	@echo "$(GREEN)  Target: Android APK (signed & aligned)$(RESET)"
	@if [ -f "$(LIB_PATH)" ]; then \
		echo "$(GREEN)  Native Library: $(LIB_SO)$(RESET)"; \
	fi
	@echo "$(GREEN)==========================================$(RESET)"
	@echo ""

# ----------------------------------------------------------------------------
#  Environment Check
# ----------------------------------------------------------------------------
check-env:
	@if [ -z "$(ANDROID_JAR)" ] || [ ! -f "$(ANDROID_JAR)" ]; then \
		echo "$(RED)--> Error: android.jar not found!$(RESET)"; \
		echo "    Please run './setup.sh' to download it,"; \
		echo "    or specify: make ANDROID_JAR=/path/to/android.jar"; \
		exit 1; \
	fi
	@if [ -z "$(AAPT2_BIN)" ]; then \
		echo "$(RED)--> Error: aapt2 not found! Please run './setup.sh'$(RESET)"; \
		exit 1; \
	fi
	@if [ -z "$(D8_BIN)" ] && [ -z "$(DX_BIN)" ]; then \
		echo "$(RED)--> Error: Neither d8 nor dx compiler found! Please run './setup.sh'$(RESET)"; \
		exit 1; \
	fi
	@if [ -z "$(APKSIGNER)" ]; then \
		echo "$(RED)--> Error: apksigner not found! Please run './setup.sh'$(RESET)"; \
		exit 1; \
	fi

# ----------------------------------------------------------------------------
#  Help Menu
# ----------------------------------------------------------------------------
help:
	@echo "$(BOLD)Android Build System (Linux Mint / apt / Termux)$(RESET)"
	@echo "$(CYAN)------------------------------------------$(RESET)"
	@echo "  $(GREEN)make$(RESET)          : Full build (dex + lib + apk)"
	@echo "  $(GREEN)make lib$(RESET)      : Build native C++ library only"
	@echo "  $(GREEN)make dex$(RESET)      : Compile Java + resources + DEX"
	@echo "  $(GREEN)make apk$(RESET)      : Package, align & sign APK"
	@echo "  $(GREEN)make install$(RESET)  : Install APK via adb or device pm"
	@echo "  $(GREEN)make uninstall$(RESET): Remove app from device"
	@echo "  $(GREEN)make clean$(RESET)    : Remove all build artifacts"
	@echo "  $(GREEN)make rmbak$(RESET)    : Delete all .bak backup files"
	@echo "  $(GREEN)make key-gen$(RESET)  : Generate release keystore"
	@echo "  $(GREEN)make help$(RESET)     : Show this help message"
	@echo "$(CYAN)------------------------------------------$(RESET)"
	@echo "  Detected android.jar : $(if $(ANDROID_JAR),$(ANDROID_JAR),$(RED)Not Found$(RESET))"
	@echo "  Detected DEX tool    : $(if $(D8_BIN),d8,$(if $(DX_BIN),dx,$(RED)Not Found$(RESET)))"
	@echo "  Detected zipalign    : $(if $(ZIPALIGN_BIN),$(ZIPALIGN_BIN),$(YELLOW)Not installed (skipping alignment)$(RESET))"
	@echo "  Detected NDK Clang   : $(if $(NDK_CLANG),$(NDK_CLANG),$(YELLOW)Host clang++ (fallback)$(RESET))"

# ----------------------------------------------------------------------------
#  Keystore Management
# ----------------------------------------------------------------------------
key-gen generate-key:
	@if [ ! -f $(KEYSTORE) ]; then \
		echo "$(YELLOW)--> Generating keystore: $(KEYSTORE)$(RESET)"; \
		keytool -genkey -v -keystore $(KEYSTORE) \
			-alias $(KEY_ALIAS) \
			-keyalg RSA -keysize 2048 -validity 10000 \
			-storepass $(KEY_PASS) -keypass $(KEY_PASS) \
			-dname "CN=AndroidApp, OU=Dev, O=App, L=Dhaka, C=BD"; \
		echo "$(GREEN)--> Keystore generated successfully$(RESET)"; \
	fi

# ----------------------------------------------------------------------------
#  Directory Setup
# ----------------------------------------------------------------------------
setup-dirs:
	@mkdir -p $(GEN_DIR)/$(PKG_PATH) $(OBJ_DIR) $(APK_DIR) $(COMPILED_RES) $(LIB_DIR)

# ----------------------------------------------------------------------------
#  Resource Compilation
# ----------------------------------------------------------------------------
compile-res: setup-dirs
	@echo "$(CYAN)--> Compiling resources with aapt2...$(RESET)"
	@aapt2 compile --dir res -o $(COMPILED_RES)/

# ----------------------------------------------------------------------------
#  Resource Linking & R.java Generation
# ----------------------------------------------------------------------------
link-res: check-env compile-res
	@echo "$(CYAN)--> Linking resources with $(ANDROID_JAR)...$(RESET)"
	@aapt2 link \
		-I $(ANDROID_JAR) \
		--manifest AndroidManifest.xml \
		--java $(GEN_DIR) \
		-o $(APK_DIR)/app-unaligned.apk \
		$(COMPILED_RES)/*.flat

# ----------------------------------------------------------------------------
#  Java Compilation
# ----------------------------------------------------------------------------
compile-java: link-res
	@echo "$(CYAN)--> Compiling Java sources...$(RESET)"
	@javac \
		-source 1.8 -target 1.8 \
		-classpath $(ANDROID_JAR) \
		-d $(OBJ_DIR) \
		$(GEN_DIR)/$(PKG_PATH)/R.java \
		$(JAVA_SRCS)

# ----------------------------------------------------------------------------
#  DEX Conversion
# ----------------------------------------------------------------------------
dex: compile-java
	@echo "$(CYAN)--> Converting bytecode to DEX format...$(RESET)"
	@if [ -n "$(D8_BIN)" ]; then \
		echo "    Using d8..."; \
		$(D8_BIN) --lib $(ANDROID_JAR) --output $(BUILD_DIR) $$(find $(OBJ_DIR) -name "*.class"); \
	elif [ -n "$(DX_BIN)" ]; then \
		echo "    Using dx..."; \
		$(DX_BIN) --dex --output=$(BUILD_DIR)/classes.dex $(OBJ_DIR); \
	else \
		echo "$(RED)Error: Neither d8 nor dx compiler found!$(RESET)"; \
		exit 1; \
	fi

# ----------------------------------------------------------------------------
#  Build Native Library (lib)
# ----------------------------------------------------------------------------
lib: setup-dirs
	@if [ -n "$(CPP_SRCS)" ]; then \
		echo "$(MAGENTA)========================================$(RESET)"; \
		echo "$(MAGENTA)  Building Native Library: $(LIB_SO)$(RESET)"; \
		echo "$(MAGENTA)========================================$(RESET)"; \
		if [ -n "$(NDK_CLANG)" ]; then \
			echo "$(YELLOW)--> Using Android NDK compiler: $(NDK_CLANG)$(RESET)"; \
			$(NDK_CLANG) -shared -fPIC -static-libstdc++ -o $(LIB_PATH) $(CPP_SRCS) || exit 1; \
		elif [ -d "/data/data/com.termux" ] || [ -f "/system/bin/app_process" ]; then \
			echo "$(YELLOW)--> Compiling directly in Android/Termux environment...$(RESET)"; \
			clang++ -shared -fPIC -static-libstdc++ -o $(LIB_PATH) $(CPP_SRCS) || exit 1; \
		else \
			echo "$(YELLOW)--> Compiling with host clang++ and JDK headers...$(RESET)"; \
			echo "$(YELLOW)    (Note: For physical arm64 Android devices, install NDK for arm64 target)$(RESET)"; \
			clang++ -shared -fPIC $(JNI_INCLUDES) -o $(LIB_PATH) $(CPP_SRCS) || exit 1; \
		fi; \
		echo "$(GREEN)--> Library built successfully: $(LIB_PATH)$(RESET)"; \
	else \
		echo "$(YELLOW)--> No C/C++ native sources found, skipping native library build.$(RESET)"; \
	fi

# ----------------------------------------------------------------------------
#  Build APK (Packaging, Aligning, and Signing)
# ----------------------------------------------------------------------------
apk: key-gen
	@echo "$(BLUE)========================================$(RESET)"
	@echo "$(BLUE)  Packaging & Signing APK$(RESET)"
	@echo "$(BLUE)========================================$(RESET)"
	@if [ ! -f $(BUILD_DIR)/classes.dex ]; then \
		echo "$(RED)--> classes.dex not found! Run 'make' or 'make dex' first$(RESET)"; \
		exit 1; \
	fi
	@if [ ! -f $(APK_DIR)/app-unaligned.apk ]; then \
		echo "$(RED)--> app-unaligned.apk not found! Run 'make' or 'make link-res' first$(RESET)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)--> Packaging APK...$(RESET)"
	@cd $(BUILD_DIR) && zip -q -u apk/app-unaligned.apk classes.dex
	@if [ -f "$(LIB_PATH)" ]; then \
		cd $(BUILD_DIR) && zip -q -u apk/app-unaligned.apk lib/arm64-v8a/$(LIB_SO); \
	fi
	@if [ -n "$(ZIPALIGN_BIN)" ]; then \
		echo "$(YELLOW)--> Aligning APK with zipalign (4-byte alignment)...$(RESET)"; \
		$(ZIPALIGN_BIN) -f -p 4 $(APK_DIR)/app-unaligned.apk $(APK_DIR)/app-aligned.apk; \
		mv -f $(APK_DIR)/app-aligned.apk $(APK_DIR)/app.apk; \
	else \
		echo "$(YELLOW)--> zipalign not found, copying unaligned APK...$(RESET)"; \
		cp $(APK_DIR)/app-unaligned.apk $(APK_DIR)/app.apk; \
	fi
	@echo "$(YELLOW)--> Signing APK with apksigner...$(RESET)"
	@apksigner sign \
		--ks $(KEYSTORE) \
		--ks-key-alias $(KEY_ALIAS) \
		--ks-pass pass:$(KEY_PASS) \
		--key-pass pass:$(KEY_PASS) \
		$(APK_DIR)/app.apk
	@echo "$(GREEN)--> Verifying APK signature...$(RESET)"
	@apksigner verify $(APK_DIR)/app.apk
	@echo "$(GREEN)--> APK successfully signed and ready: $(APK_DIR)/app.apk$(RESET)"
	@echo ""

# ----------------------------------------------------------------------------
#  APK Signing Alias
# ----------------------------------------------------------------------------
sign: apk

# ----------------------------------------------------------------------------
#  Installation & Uninstallation
# ----------------------------------------------------------------------------
install:
	@echo "$(YELLOW)--> Installing APK...$(RESET)"
	@if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then \
		adb install -r $(APK_DIR)/app.apk; \
	elif command -v su >/dev/null 2>&1; then \
		su -c "pm install -r $(APK_DIR)/app.apk"; \
	else \
		echo "$(RED)--> Neither adb nor su (pm) available for installation.$(RESET)"; \
		echo "    You can manually install $(APK_DIR)/app.apk on your device."; \
		exit 1; \
	fi
	@echo "$(GREEN)--> Installed successfully$(RESET)"

uninstall:
	@echo "$(YELLOW)--> Uninstalling $(PKG_NAME)...$(RESET)"
	@if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then \
		adb uninstall $(PKG_NAME); \
	elif command -v su >/dev/null 2>&1; then \
		su -c "pm uninstall $(PKG_NAME)"; \
	else \
		echo "$(RED)--> Neither adb nor su available to uninstall.$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)--> Uninstalled successfully$(RESET)"

# ----------------------------------------------------------------------------
#  Cleanup
# ----------------------------------------------------------------------------
clean:
	@echo "$(YELLOW)--> Cleaning build environment...$(RESET)"
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)--> Clean complete$(RESET)"

rmbak:
	@echo "$(YELLOW)--> Removing all .bak backup files...$(RESET)"
	@find . -type f -name "*.bak" -delete
	@echo "$(GREEN)--> Done$(RESET)"
