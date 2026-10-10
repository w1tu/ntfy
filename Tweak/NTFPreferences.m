#import "NTFPreferences.h"

static CGFloat NTFClampedFloat(NSString *key, CGFloat min, CGFloat max) {
	id value = NTFCopyPreference(key);
	CGFloat number = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : [NTFDefaultPreferences()[key] doubleValue];
	if (!isfinite(number)) number = [NTFDefaultPreferences()[key] doubleValue];
	return MIN(MAX(number, min), max);
}

static BOOL NTFBool(NSString *key) {
	id value = NTFCopyPreference(key);
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : [NTFDefaultPreferences()[key] boolValue];
}

@implementation NTFPreferences

+ (instancetype)shared {
	static NTFPreferences *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [self new];
		[shared reload];
	});
	return shared;
}

- (void)reload {
	CFPreferencesAppSynchronize((__bridge CFStringRef)NTF_DOMAIN);

	_enabled = NTFBool(NTF_KEY_ENABLED);
	_style = NTFClampedFloat(NTF_KEY_STYLE, 0, 1) >= 0.5 ? NTFDotStyleHollow : NTFDotStyleFilled;
	_color = NTFColorFromHex(NTFCopyPreference(NTF_KEY_COLOR)) ?: NTFColorFromHex(NTFDefaultPreferences()[NTF_KEY_COLOR]);
	_adaptive = NTFBool(NTF_KEY_ADAPTIVE);
	_pastel = NTFBool(NTF_KEY_PASTEL);
	_size = round(NTFClampedFloat(NTF_KEY_SIZE, 6, 24));
	_border = round(NTFClampedFloat(NTF_KEY_BORDER, 1, 5) * 2.0) / 2.0;
	_opacity = round(NTFClampedFloat(NTF_KEY_OPACITY, 20, 100)) / 100.0;
	_offsetX = round(NTFClampedFloat(NTF_KEY_OFFSET_X, -12, 12));
	_offsetY = round(NTFClampedFloat(NTF_KEY_OFFSET_Y, -12, 12));
}

@end
