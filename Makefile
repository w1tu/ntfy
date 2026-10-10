TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME ?= rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ntfy
ntfy_FILES = Tweak/Tweak.x Tweak/NTFPreferences.m Tweak/NTFDotView.m Tweak/NTFColorExtractor.m
ntfy_CFLAGS = -fobjc-arc -Wall -Wno-unused-function
ntfy_FRAMEWORKS = UIKit CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

# linux toolchain can't do the new arm64e abi, build on macos for that
ifeq ($(THEOS_PLATFORM_NAME),linux)
ifneq ($(filter arm64e,$(ARCHS)),)
$(error arm64e cannot be built with the Linux toolchain; build on macOS or pass ARCHS=arm64)
endif
endif
