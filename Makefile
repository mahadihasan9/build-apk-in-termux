# ============================================================================
#  Android Application Build System
#  Java 8 bytecode (compatible with dx) + NDK cross-compiler
#  Supports Termux and Linux Mint / Ubuntu / Debian
# ============================================================================

PROJECT_DIR  := $(shell pwd)
ANDROID_JAR  ?= $(firstword \
	$(wildcard $(HOME)/android-sdk/android.jar) \
	$(wildcard /usr/lib/android-sdk/platforms/android-*/android.jar) \
	$(wildcard $(ANDROID_HOME)/platforms/android-*/android.jar))
KEYSTORE     := my-release-key.jks
KEY_ALIAS    := androidapk
KEY_PASS     := learningkey
PKG_NAME     := com.example.myfirstapp

UNAME_M      := $(shell uname -m)
IS_TERMUX    := $(if $(TERMUX_VERSION),1,$(if $(wildcard /data/data/com.termux),1,0))

BUILD_ARCH   := arm64-v8a

BUILD_DIR    := build
GEN_DIR      := $(BUILD_DIR)/gen
OBJ_DIR      := $(BUILD_DIR)/obj
APK_DIR      := $(BUILD_DIR)/apk
COMPILED_RES := $(BUILD_DIR)/compiled_res
LIB_DIR      := $(BUILD_DIR)/lib/$(BUILD_ARCH)

JAVA_SRCS    := $(shell find src -name "*.java")
PKG_PATH     := com/example/myfirstapp

CPP_SRC      := $(firstword $(shell find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak" 2>/dev/null))
LIB_NAME     := $(if $(CPP_SRC),$(basename $(notdir $(CPP_SRC))),test)
LIB_SO       := lib$(LIB_NAME).so
LIB_PATH     := $(LIB_DIR)/$(LIB_SO)

# ============================================================================
#  Build-tools
# ============================================================================
ifeq ($(IS_TERMUX),1)
    AAPT2     := $(shell command -v aapt2 2>/dev/null)
    D8        := $(shell command -v d8 2>/dev/null)
    DX        := $(shell command -v dx 2>/dev/null)
    ZIPALIGN  := $(shell command -v zipalign 2>/dev/null)
    APKSIGNER := $(shell command -v apksigner 2>/dev/null)
else
    BT_DIR := $(firstword \
        $(wildcard $(HOME)/android-sdk/build-tools/34.0.0) \
        $(wildcard $(HOME)/android-sdk/build-tools/*) \
        $(wildcard /usr/lib/android-sdk/build-tools/*))
    AAPT2     := $(if $(BT_DIR),$(BT_DIR)/aapt2,$(shell command -v aapt2 2>/dev/null))
    D8        := $(if $(BT_DIR),$(BT_DIR)/d8,$(shell command -v d8 2>/dev/null))
    DX        := $(shell command -v dx 2>/dev/null)
    ZIPALIGN  := $(if $(BT_DIR),$(BT_DIR)/zipalign,$(shell command -v zipalign 2>/dev/null))
    APKSIGNER := $(if $(BT_DIR),$(BT_DIR)/apksigner,$(shell command -v apksigner 2>/dev/null))
endif

# ============================================================================
#  NDK
# ============================================================================
ifeq ($(IS_TERMUX),1)
    CXX             := $(shell command -v aarch64-linux-android-clang++ 2>/dev/null || command -v clang++ 2>/dev/null)
    NDK_TARGET_FLAG :=
    NDK_HOME        :=
else
    NDK_HOME        := $(if $(ANDROID_NDK_HOME),$(ANDROID_NDK_HOME),$(HOME)/android-ndk-r27c)
    NDK_BIN         := $(NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin
    CXX             := $(NDK_BIN)/aarch64-linux-android21-clang++
    NDK_TARGET_FLAG := --target=aarch64-linux-android21
endif

ifeq ($(JAVA_HOME),)
    JAVA_HOME := $(shell dirname $$(dirname $$(readlink -f $$(which javac 2>/dev/null) 2>/dev/null) 2>/dev/null) 2>/dev/null)
endif
JNI_INC      := $(if $(wildcard $(JAVA_HOME)/include),-I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux,)

# Colors
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
MAGENTA:= \033[0;35m
CYAN   := \033[0;36m
RESET  := \033[0m
BOLD   := \033[1m

.PHONY: all help clean install uninstall setup-dirs \
        compile-res link-res compile-java dex \
        key-gen generate-key rmbak lib apk sign

# ----------------------------------------------------------------------------
all: dex lib apk
	@echo ""
	@echo "$(GREEN)==========================================$(RESET)"
	@echo "$(GREEN)  BUILD SUCCESSFUL: $(APK_DIR)/app.apk$(RESET)"
	@echo "$(GREEN)  Architecture: $(BUILD_ARCH)$(RESET)"
	@echo "$(GREEN)  Native Library: $(LIB_SO)$(RESET)"
	@echo "$(GREEN)==========================================$(RESET)"
	@echo ""

# ----------------------------------------------------------------------------
help:
	@echo "$(BOLD)Android Build System - Available Targets$(RESET)"
	@echo "$(CYAN)------------------------------------------$(RESET)"
	@echo "  $(GREEN)make$(RESET)          : Full build (dex + lib + apk)"
	@echo "  $(GREEN)make lib$(RESET)      : Build native library only"
	@echo "  $(GREEN)make dex$(RESET)      : Compile Java + resources + DEX"
	@echo "  $(GREEN)make apk$(RESET)      : Build APK from existing files"
	@echo "  $(GREEN)make install$(RESET)  : Install APK"
	@echo "  $(GREEN)make uninstall$(RESET): Remove app"
	@echo "  $(GREEN)make clean$(RESET)    : Remove build artifacts"
	@echo "  $(GREEN)make key-gen$(RESET)  : Generate keystore"
	@echo "  $(GREEN)make help$(RESET)     : Show this help"
	@echo "$(CYAN)------------------------------------------$(RESET)"
	@echo "  Environment : $(if $(filter 1,$(IS_TERMUX)),Termux,Linux)"
	@echo "  ARCH        : $(BUILD_ARCH)"
	@echo "  CXX         : $(CXX)"
	@echo "  NDK_HOME    : $(NDK_HOME)"
	@echo "  JAVA_HOME   : $(JAVA_HOME)"
	@echo "  javac       : $$(javac -version 2>&1)"
	@echo "  AAPT2       : $(AAPT2)"
	@echo "  D8          : $(D8)"
	@echo "  DX          : $(DX)"
	@echo "  ZIPALIGN    : $(ZIPALIGN)"
	@echo "  APKSIGNER   : $(APKSIGNER)"
	@echo "  ANDROID_JAR : $(ANDROID_JAR)"
	@echo "$(CYAN)------------------------------------------$(RESET)"

# ----------------------------------------------------------------------------
key-gen generate-key:
	@if [ ! -f $(KEYSTORE) ]; then \
		echo "$(YELLOW)--> Generating keystore: $(KEYSTORE)$(RESET)"; \
		keytool -genkey -v -keystore $(KEYSTORE) \
			-alias $(KEY_ALIAS) \
			-keyalg RSA -keysize 2048 -validity 10000 \
			-storepass $(KEY_PASS) -keypass $(KEY_PASS) \
			-dname "CN=Mahadi, OU=Dev, O=App, L=Dhaka, C=BD"; \
		echo "$(GREEN)--> Keystore generated$(RESET)"; \
	fi

setup-dirs:
	@mkdir -p $(GEN_DIR)/$(PKG_PATH) $(OBJ_DIR) $(APK_DIR) $(COMPILED_RES) $(LIB_DIR)

# ----------------------------------------------------------------------------
compile-res: setup-dirs
	@echo "$(CYAN)--> Compiling resources...$(RESET)"
	@if [ -z "$(AAPT2)" ] || [ ! -x "$(AAPT2)" ]; then \
		echo "$(RED)Error: aapt2 not found.$(RESET)"; exit 1; \
	fi
	@$(AAPT2) compile --dir res -o $(COMPILED_RES)/

link-res: compile-res
	@echo "$(CYAN)--> Linking resources...$(RESET)"
	@$(AAPT2) link \
		-I $(ANDROID_JAR) \
		--manifest AndroidManifest.xml \
		--java $(GEN_DIR) \
		-o $(APK_DIR)/app-unaligned.apk \
		$(COMPILED_RES)/*.flat

# ----------------------------------------------------------------------------
#  Java compilation
#    -source 8 -target 8      → bytecode version 52 (required for dx)
#    -Xlint:-options          → suppress "source 8 obsolete" warnings on JDK 21
#    -g:none                  → no debug info (avoids further D8 edge cases)
# ----------------------------------------------------------------------------
compile-java: link-res
	@echo "$(CYAN)--> Compiling Java sources (JDK: $$(javac -version 2>&1))...$(RESET)"
	@javac \
		-source 8 -target 8 \
		-Xlint:-options \
		-g:none \
		-classpath $(ANDROID_JAR) \
		-d $(OBJ_DIR) \
		$(GEN_DIR)/$(PKG_PATH)/R.java \
		$(JAVA_SRCS)

# ----------------------------------------------------------------------------
#  DEX conversion
#    Prefer dx (works on JDK 21 with Java-8 bytecode).
#    D8 is only used as a last resort — it crashes on JDK 21 with
#    anonymous inner classes (R8 8.2.x bug).
# ----------------------------------------------------------------------------
dex: compile-java
	@echo "$(CYAN)--> Converting to DEX format...$(RESET)"
	@if [ -n "$(DX)" ] && [ -x "$(DX)" ]; then \
		echo "   Using dx: $(DX)"; \
		$(DX) --dex --output=$(BUILD_DIR)/classes.dex $(OBJ_DIR); \
	elif [ -n "$(D8)" ] && [ -x "$(D8)" ]; then \
		echo "   Using d8 (fallback): $(D8)"; \
		$(D8) --lib $(ANDROID_JAR) --min-api 21 --output $(BUILD_DIR) $$(find $(OBJ_DIR) -name "*.class"); \
	else \
		echo "$(RED)Error: neither dx nor d8 found.$(RESET)"; exit 1; \
	fi

# ----------------------------------------------------------------------------
lib: setup-dirs
	@echo "$(MAGENTA)========================================$(RESET)"
	@echo "$(MAGENTA)  Building Native Library Only$(RESET)"
	@echo "$(MAGENTA)========================================$(RESET)"
	@if [ -d "src/jni" ] && [ $$(find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak" | wc -l) -gt 0 ]; then \
		echo "$(YELLOW)--> Compiling with: $(CXX)$(RESET)"; \
		mkdir -p $(LIB_DIR); \
		$(CXX) -shared -fPIC -static-libstdc++ $(NDK_TARGET_FLAG) $(JNI_INC) \
			-o $(LIB_PATH) \
			$$(find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak"); \
		echo "$(GREEN)--> Library built: $(LIB_PATH)$(RESET)"; \
	else \
		echo "$(RED)--> No C++ source files found in src/jni/$(RESET)"; \
		exit 1; \
	fi
	@echo ""

# ----------------------------------------------------------------------------
apk: key-gen
	@echo "$(BLUE)========================================$(RESET)"
	@echo "$(BLUE)  Building APK Only (from existing build)$(RESET)"
	@echo "$(BLUE)========================================$(RESET)"
	@if [ ! -f $(BUILD_DIR)/classes.dex ]; then \
		echo "$(RED)--> classes.dex not found! Run 'make dex' first$(RESET)"; \
		exit 1; \
	fi
	@if [ ! -f $(LIB_PATH) ]; then \
		echo "$(RED)--> $(LIB_SO) not found! Run 'make lib' first$(RESET)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)--> Packaging APK...$(RESET)"
	@cd $(BUILD_DIR) && zip -q -u apk/app-unaligned.apk classes.dex lib/$(BUILD_ARCH)/$(LIB_SO)
	@if [ -n "$(ZIPALIGN)" ] && [ -x "$(ZIPALIGN)" ]; then \
		$(ZIPALIGN) -f -p 4 $(APK_DIR)/app-unaligned.apk $(APK_DIR)/app.apk; \
	else \
		echo "$(YELLOW)--> zipalign not available, skipping alignment$(RESET)"; \
		cp $(APK_DIR)/app-unaligned.apk $(APK_DIR)/app.apk; \
	fi
	@echo "$(YELLOW)--> Signing APK...$(RESET)"
	@$(APKSIGNER) sign \
		--ks $(KEYSTORE) \
		--ks-key-alias $(KEY_ALIAS) \
		--ks-pass pass:$(KEY_PASS) \
		--key-pass pass:$(KEY_PASS) \
		$(APK_DIR)/app.apk
	@echo "$(GREEN)--> APK signed: $(APK_DIR)/app.apk$(RESET)"
	@echo ""

sign: apk

# ----------------------------------------------------------------------------
install:
	@if [ -d "/data/data/com.termux" ] || [ -n "$$TERMUX_VERSION" ]; then \
		echo "$(YELLOW)--> Installing APK via root (su)...$(RESET)"; \
		if command -v su >/dev/null 2>&1; then \
			su -c "pm install -r $(APK_DIR)/app.apk"; \
		else \
			echo "$(RED)Error: Root (su) required.$(RESET)"; exit 1; \
		fi; \
	else \
		echo "$(YELLOW)--> Installing via ADB...$(RESET)"; \
		if ! command -v adb >/dev/null 2>&1; then \
			echo "$(RED)Error: adb not installed.$(RESET)"; exit 1; \
		fi; \
		adb install -r $(APK_DIR)/app.apk; \
	fi

uninstall:
	@if [ -d "/data/data/com.termux" ] || [ -n "$$TERMUX_VERSION" ]; then \
		su -c "pm uninstall $(PKG_NAME)"; \
	else \
		adb uninstall $(PKG_NAME); \
	fi

# ----------------------------------------------------------------------------
clean:
	@echo "$(YELLOW)--> Cleaning build environment...$(RESET)"
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)--> Clean complete$(RESET)"

rmbak:
	@find . -type f -name "*.bak" -delete
	@echo "$(GREEN)--> Done$(RESET)"