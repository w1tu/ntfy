TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ntfyPrefs
ntfyPrefs_FILES = NTFRootListController.m NTFColorCell.m
ntfyPrefs_CFLAGS = -fobjc-arc -Wall -Wno-unused-function
ntfyPrefs_FRAMEWORKS = UIKit QuartzCore
ntfyPrefs_PRIVATE_FRAMEWORKS = Preferences
ntfyPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
