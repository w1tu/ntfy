#import "NTFRootListController.h"
#import "../Shared/NTFShared.h"

extern NSString *const NTFPreviewNeedsUpdateNotification;

@implementation NTFRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	if (!key) return [super readPreferenceValue:specifier];
	return NTFCopyPreference(key) ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	if (!key) {
		[super setPreferenceValue:value specifier:specifier];
		return;
	}
	if ([value isKindOfClass:[NSNumber class]] && [specifier propertyForKey:@"min"]) {
		CGFloat step = [[specifier propertyForKey:@"ntfStep"] doubleValue] ?: 1.0;
		value = @(round([value doubleValue] / step) * step);
	}
	CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)NTF_DOMAIN);
	[self preferencesDidChange];
	if ([key isEqualToString:NTF_KEY_STYLE]) [self reloadSpecifierID:NTF_KEY_BORDER animated:NO];
}

- (void)preferencesDidChange {
	CFPreferencesAppSynchronize((__bridge CFStringRef)NTF_DOMAIN);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NTF_NOTIFICATION), NULL, NULL, YES);
	[[NSNotificationCenter defaultCenter] postNotificationName:NTFPreviewNeedsUpdateNotification object:nil];
}

- (void)restoreDefaults:(PSSpecifier *)specifier {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restore Defaults?"
	                                                               message:@"All ntfy settings will return to their original values."
	                                                        preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		for (NSString *key in NTFDefaultPreferences()) {
			CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)NTF_DOMAIN);
		}
		[self preferencesDidChange];
		[self reloadSpecifiers];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

@end
