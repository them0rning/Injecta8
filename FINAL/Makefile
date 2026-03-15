export THEOS ?= /opt/theos
export TARGET := iphone:clang:16.5:15.0
export ARCHS  := arm64
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

# ── Tweak ──────────────────────────────────────────────────────────────────
TWEAK_NAME = CameraInject
CameraInject_FILES      = Tweak.xm SampleBufferFactory.mm
CameraInject_FRAMEWORKS = AVFoundation CoreMedia CoreVideo UIKit Foundation CoreFoundation
CameraInject_CFLAGS     = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include
CameraInject_CCFLAGS    = -fobjc-arc -std=c++17
CameraInject_LDFLAGS    = -lsubstrate

include $(THEOS)/makefiles/tweak.mk

# ── Preference Bundle ──────────────────────────────────────────────────────
BUNDLE_NAME = CamInjectPrefs
CamInjectPrefs_FILES              = Prefs/CamInjectPrefs.mm
CamInjectPrefs_FRAMEWORKS         = UIKit Foundation CoreGraphics
CamInjectPrefs_PRIVATE_FRAMEWORKS = Preferences
CamInjectPrefs_CFLAGS             = -fobjc-arc
CamInjectPrefs_INSTALL_PATH       = /Library/PreferenceBundles
CamInjectPrefs_RESOURCE_DIRS      = Prefs/Resources

include $(THEOS)/makefiles/bundle.mk
