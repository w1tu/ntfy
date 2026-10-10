#import "NTFPreferences.h"
#import <rootless.h>

// read the plist directly, springboard's cfprefsd lookups miss the jailbreak redirect
static NSDictionary *NTFStoredPreferences(void) {
	NSString *name = [NTF_DOMAIN stringByAppendingPathExtension:@"plist"];
	NSArray<NSString *> *paths = @[
		[ROOT_PATH_NS(@"/var/mobile/Library/Preferences") stringByAppendingPathComponent:name],
		[@"/var/mobile/Library/Preferences" stringByAppendingPathComponent:name],
	];
	for (NSString *path in paths) {
		NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:path];
		if (stored) return stored;
	}

	CFPreferencesAppSynchronize((__bridge CFStringRef)NTF_DOMAIN);
	CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)NTF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!keys) return @{};
	CFDictionaryRef values = CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)NTF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	CFRelease(keys);
	return values ? (__bridge_transfer NSDictionary *)values : @{};
}

@implementation NTFPreferences {
	NSDictionary *_stored;
}

+ (instancetype)shared {
	static NTFPreferences *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [self new];
		[shared reload];
	});
	return shared;
}

- (id)valueForKey:(NSString *)key ofClass:(Class)cls {
	id value = _stored[key];
	return [value isKindOfClass:cls] ? value : NTFDefaultPreferences()[key];
}

- (BOOL)boolForKey:(NSString *)key {
	return [[self valueForKey:key ofClass:[NSNumber class]] boolValue];
}

- (CGFloat)floatForKey:(NSString *)key min:(CGFloat)min max:(CGFloat)max {
	CGFloat number = [[self valueForKey:key ofClass:[NSNumber class]] doubleValue];
	if (!isfinite(number)) number = [NTFDefaultPreferences()[key] doubleValue];
	return MIN(MAX(number, min), max);
}

- (void)reload {
	_stored = NTFStoredPreferences();

	_enabled = [self boolForKey:NTF_KEY_ENABLED];
	_style = [self floatForKey:NTF_KEY_STYLE min:0 max:1] >= 0.5 ? NTFDotStyleHollow : NTFDotStyleFilled;
	_color = NTFColorFromHex([self valueForKey:NTF_KEY_COLOR ofClass:[NSString class]]) ?: NTFColorFromHex(NTFDefaultPreferences()[NTF_KEY_COLOR]);
	_adaptive = [self boolForKey:NTF_KEY_ADAPTIVE];
	_pastel = [self boolForKey:NTF_KEY_PASTEL];
	_size = round([self floatForKey:NTF_KEY_SIZE min:6 max:24]);
	_border = round([self floatForKey:NTF_KEY_BORDER min:1 max:5] * 2.0) / 2.0;
	_opacity = round([self floatForKey:NTF_KEY_OPACITY min:20 max:100]) / 100.0;
	_offsetX = round([self floatForKey:NTF_KEY_OFFSET_X min:-12 max:12]);
	_offsetY = round([self floatForKey:NTF_KEY_OFFSET_Y min:-12 max:12]);
}

- (NSDictionary *)storedValues {
	return _stored;
}

@end
