TARGET := iphone:clang:16.5:15.0
ARCHS ?= arm64 arm64e
THEOS_PACKAGE_SCHEME ?= rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

# linux toolchain can't do the new arm64e abi, build on macos for that
ifeq ($(THEOS_PLATFORM_NAME),linux)
ifneq ($(filter arm64e,$(ARCHS)),)
$(warning Linux toolchain: building arm64 only; arm64e devices need a macOS build)
override ARCHS := $(filter-out arm64e,$(ARCHS))
endif
endif
export ARCHS

TWEAK_NAME = ntfy
ntfy_FILES = Tweak/Tweak.x Tweak/NTFPreferences.m Tweak/NTFDotView.m Tweak/NTFColorExtractor.m
ntfy_CFLAGS = -fobjc-arc -Wall -Wno-unused-function
ntfy_FRAMEWORKS = UIKit CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

# sileo icon + header
internal-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/ntfy"$(ECHO_END)
	$(ECHO_NOTHING)cp assets/ntfy-icon-256.png "$(THEOS_STAGING_DIR)/Library/Application Support/ntfy/icon.png"$(ECHO_END)
	$(ECHO_NOTHING)cp assets/ntfy-sileo-header.png "$(THEOS_STAGING_DIR)/Library/Application Support/ntfy/banner.png"$(ECHO_END)
