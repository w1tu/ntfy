#import <UIKit/UIKit.h>
#import <rootless.h>

#define NTF_DOMAIN @"com.witu.ntfy"
#define NTF_NOTIFICATION "com.witu.ntfy/prefs"

#define NTF_KEY_ENABLED  @"enabled"
#define NTF_KEY_STYLE    @"style"
#define NTF_KEY_COLOR    @"color"
#define NTF_KEY_ADAPTIVE @"adaptive"
#define NTF_KEY_PASTEL   @"pastel"
#define NTF_KEY_SIZE     @"size"
#define NTF_KEY_BORDER   @"border"
#define NTF_KEY_OPACITY  @"opacity"
#define NTF_KEY_OFFSET_X @"offsetX"
#define NTF_KEY_OFFSET_Y @"offsetY"

typedef NS_ENUM(NSInteger, NTFDotStyle) {
	NTFDotStyleFilled = 0,
	NTFDotStyleHollow = 1,
};

static inline NSDictionary<NSString *, id> *NTFDefaultPreferences(void) {
	return @{
		NTF_KEY_ENABLED: @YES,
		NTF_KEY_STYLE: @(NTFDotStyleFilled),
		NTF_KEY_COLOR: @"#FF3B30",
		NTF_KEY_ADAPTIVE: @NO,
		NTF_KEY_PASTEL: @NO,
		NTF_KEY_SIZE: @12,
		NTF_KEY_BORDER: @2,
		NTF_KEY_OPACITY: @100,
		NTF_KEY_OFFSET_X: @2,
		NTF_KEY_OFFSET_Y: @2,
	};
}

static inline NSArray<NSString *> *NTFPresetColors(void) {
	return @[
		@"#FF3B30", @"#FF9500", @"#FFCC00", @"#34C759", @"#00C7BE", @"#32ADE6",
		@"#007AFF", @"#5856D6", @"#AF52DE", @"#FF2D55", @"#A2845E", @"#8E8E93", @"#FFFFFF",
	];
}

static inline NSArray<NSString *> *NTFPresetColorNames(void) {
	return @[
		@"Red", @"Orange", @"Yellow", @"Green", @"Mint", @"Cyan",
		@"Blue", @"Indigo", @"Purple", @"Pink", @"Brown", @"Grey", @"White",
	];
}

static inline UIColor *NTFColorFromHex(NSString *hex) {
	if (![hex isKindOfClass:[NSString class]]) return nil;
	NSString *clean = [hex stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"# "]];
	if (clean.length != 6) return nil;
	unsigned int value = 0;
	if (![[NSScanner scannerWithString:clean] scanHexInt:&value]) return nil;
	return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
	                       green:((value >> 8) & 0xFF) / 255.0
	                        blue:(value & 0xFF) / 255.0
	                       alpha:1.0];
}

static inline NSString *NTFHexFromColor(UIColor *color) {
	CGFloat r = 0, g = 0, b = 0, a = 0;
	if (![color getRed:&r green:&g blue:&b alpha:&a]) return nil;
	int ri = (int)lround(MIN(MAX(r, 0.0), 1.0) * 255.0);
	int gi = (int)lround(MIN(MAX(g, 0.0), 1.0) * 255.0);
	int bi = (int)lround(MIN(MAX(b, 0.0), 1.0) * 255.0);
	return [NSString stringWithFormat:@"#%02X%02X%02X", ri, gi, bi];
}

// dot just off the top-right corner, sizes are for a 60pt icon
static inline CGRect NTFDotFrame(CGRect imageFrame, CGFloat size, CGFloat offsetX, CGFloat offsetY, CGFloat screenScale) {
	CGFloat unit = CGRectGetWidth(imageFrame) / 60.0;
	if (unit <= 0) unit = 1;
	CGFloat scale = screenScale > 0 ? screenScale : 2;
	CGFloat diameter = MAX(round(size * unit * scale) / scale, 2.0 / scale);
	CGFloat outset = size * 0.2;
	CGFloat centerX = CGRectGetMaxX(imageFrame) + (outset + offsetX) * unit;
	CGFloat centerY = CGRectGetMinY(imageFrame) - (outset + offsetY) * unit;
	return CGRectMake(round((centerX - diameter / 2.0) * scale) / scale,
	                  round((centerY - diameter / 2.0) * scale) / scale,
	                  diameter, diameter);
}

#pragma mark - Settings storage

// own plist instead of cfprefsd, which lagged and got redirected by the jailbreak
static inline NSString *NTFSettingsPath(void) {
	return ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.witu.ntfy.settings.plist");
}

static inline NSDictionary<NSString *, id> *NTFLoadSettings(void) {
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:NTFSettingsPath()];
	if (settings) return settings;

	// old cfprefsd plist
	for (NSString *path in @[ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.witu.ntfy.plist"),
	                         @"/var/mobile/Library/Preferences/com.witu.ntfy.plist"]) {
		NSDictionary *legacy = [NSDictionary dictionaryWithContentsOfFile:path];
		if (legacy) return legacy;
	}
	return @{};
}

static inline BOOL NTFWriteSettings(NSDictionary<NSString *, id> *settings) {
	NSString *path = NTFSettingsPath();
	[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
	                          withIntermediateDirectories:YES attributes:nil error:nil];
	return [settings writeToURL:[NSURL fileURLWithPath:path] error:nil];
}

static inline BOOL NTFSaveSetting(NSString *key, id value) {
	NSMutableDictionary *settings = [NTFLoadSettings() mutableCopy];
	if (value) settings[key] = value;
	else [settings removeObjectForKey:key];
	return NTFWriteSettings(settings);
}

static inline void NTFPostSettingsChanged(void) {
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NTF_NOTIFICATION), NULL, NULL, YES);
}

static inline id NTFCopyPreference(NSString *key) {
	return NTFLoadSettings()[key] ?: NTFDefaultPreferences()[key];
}
