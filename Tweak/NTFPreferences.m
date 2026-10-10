#import "NTFPreferences.h"

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
	_stored = NTFLoadSettings();

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
