# ============================================================================
#  Android Application Build System
#  Termux Makefile for Java + NDK (C/C++) projects
#  Target: arm64-v8a only
# ============================================================================

# ----------------------------------------------------------------------------
#  Toolchain & Environment
# ----------------------------------------------------------------------------
PROJECT_DIR  := $(shell pwd)
ANDROID_JAR  := $(HOME)/android-sdk/android.jar
KEYSTORE     := my-release-key.jks
KEY_ALIAS    := androidapk
KEY_PASS     := learningkey
PKG_NAME     := com.example.myfirstapp

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
JAVA_SRCS    := $(shell find src -name "*.java")
PKG_PATH     := com/example/myfirstapp

CPP_SRC      := $(firstword $(shell find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak" 2>/dev/null))
LIB_NAME     := $(if $(CPP_SRC),$(basename $(notdir $(CPP_SRC))),test)
LIB_SO       := lib$(LIB_NAME).so
LIB_PATH     := $(LIB_DIR)/$(LIB_SO)

# ----------------------------------------------------------------------------
#  Colors for output
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
.PHONY: all help clean install uninstall setup-dirs \
        compile-res link-res compile-java dex \
        key-gen generate-key rmbak lib apk sign

# ----------------------------------------------------------------------------
#  Default Target: Build Everything
# ----------------------------------------------------------------------------
all: lib apk
	@echo ""
	@echo "$(GREEN)==========================================$(RESET)"
	@echo "$(GREEN)  BUILD SUCCESSFUL: $(APK_DIR)/app.apk$(RESET)"
	@echo "$(GREEN)  Architecture: arm64-v8a$(RESET)"
	@echo "$(GREEN)  Native Library: $(LIB_SO)$(RESET)"
	@echo "$(GREEN)==========================================$(RESET)"
	@echo ""

# ----------------------------------------------------------------------------
#  Help Menu
# ----------------------------------------------------------------------------
help:
	@echo "$(BOLD)Android Build System - Available Targets$(RESET)"
	@echo "$(CYAN)------------------------------------------$(RESET)"
	@echo "  $(GREEN)make$(RESET)          : Full build (lib + apk)"
	@echo "  $(GREEN)make lib$(RESET)      : Build native library only"
	@echo "  $(GREEN)make apk$(RESET)      : Build APK from existing files"
	@echo "  $(GREEN)make install$(RESET)  : Install APK (requires root)"
	@echo "  $(GREEN)make uninstall$(RESET): Remove app from device"
	@echo "  $(GREEN)make clean$(RESET)    : Remove all build artifacts"
	@echo "  $(GREEN)make rmbak$(RESET)    : Delete all .bak files"
	@echo "  $(GREEN)make key-gen$(RESET)  : Generate keystore only"
	@echo "  $(GREEN)make help$(RESET)     : Show this message"
	@echo "$(CYAN)------------------------------------------$(RESET)"
	@echo "  $(YELLOW)make lib → compiles C++ files only$(RESET)"
	@echo "  $(YELLOW)make apk → packages & signs APK from existing build$(RESET)"

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
			-dname "CN=Mahadi, OU=Dev, O=App, L=Dhaka, C=BD"; \
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
	@echo "$(CYAN)--> Compiling resources...$(RESET)"
	@aapt2 compile --dir res -o $(COMPILED_RES)/

# ----------------------------------------------------------------------------
#  Resource Linking & R.java Generation
# ----------------------------------------------------------------------------
link-res: compile-res
	@echo "$(CYAN)--> Linking resources...$(RESET)"
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
	@echo "$(CYAN)--> Converting to DEX format...$(RESET)"
	@dx --dex --output=$(BUILD_DIR)/classes.dex $(OBJ_DIR)

# ----------------------------------------------------------------------------
#  Build Native Library Only (lib)
# ----------------------------------------------------------------------------
lib: setup-dirs
	@echo "$(MAGENTA)========================================$(RESET)"
	@echo "$(MAGENTA)  Building Native Library Only$(RESET)"
	@echo "$(MAGENTA)========================================$(RESET)"
	@if [ -d "src/jni" ] && [ $$(find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak" | wc -l) -gt 0 ]; then \
		echo "$(YELLOW)--> Building: $(LIB_SO) for arm64-v8a$(RESET)"; \
		mkdir -p $(LIB_DIR); \
		aarch64-linux-android-clang++ -shared -fPIC -static-libstdc++ \
			-o $(LIB_PATH) \
			$$(find src/jni \( -name "*.cpp" -o -name "*.c" \) ! -name "*.bak"); \
		echo "$(GREEN)--> Library built: $(LIB_PATH)$(RESET)"; \
	else \
		echo "$(RED)--> No C++ source files found in src/jni/$(RESET)"; \
		exit 1; \
	fi
	@echo ""

# ----------------------------------------------------------------------------
#  Build APK Only (from existing build artifacts)
# ----------------------------------------------------------------------------
apk: key-gen
	@echo "$(BLUE)========================================$(RESET)"
	@echo "$(BLUE)  Building APK Only (from existing build)$(RESET)"
	@echo "$(BLUE)========================================$(RESET)"
	@if [ ! -f $(BUILD_DIR)/classes.dex ]; then \
		echo "$(RED)--> classes.dex not found! Run 'make' or 'make dex' first$(RESET)"; \
		exit 1; \
	fi
	@if [ ! -f $(LIB_PATH) ]; then \
		echo "$(RED)--> $(LIB_SO) not found! Run 'make lib' first$(RESET)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)--> Packaging APK from existing files...$(RESET)"
	@cp $(APK_DIR)/app-unaligned.apk $(APK_DIR)/app.apk
	@cd $(BUILD_DIR) && zip -ur apk/app.apk classes.dex lib/arm64-v8a/$(LIB_SO)
	@echo "$(YELLOW)--> Signing APK...$(RESET)"
	@apksigner sign \
		--ks $(KEYSTORE) \
		--ks-key-alias $(KEY_ALIAS) \
		--ks-pass pass:$(KEY_PASS) \
		--key-pass pass:$(KEY_PASS) \
		$(APK_DIR)/app.apk
	@echo "$(GREEN)--> APK signed: $(APK_DIR)/app.apk$(RESET)"
	@echo ""

# ----------------------------------------------------------------------------
#  APK Signing (used by all)
# ----------------------------------------------------------------------------
sign: apk

# ----------------------------------------------------------------------------
#  Installation & Uninstallation
# ----------------------------------------------------------------------------
install:
	@echo "$(YELLOW)--> Installing APK...$(RESET)"
	@su -c "pm install -r $(APK_DIR)/app.apk"
	@echo "$(GREEN)--> Installed successfully$(RESET)"

uninstall:
	@echo "$(YELLOW)--> Uninstalling $(PKG_NAME)...$(RESET)"
	@su -c "pm uninstall $(PKG_NAME)"
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