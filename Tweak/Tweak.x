#import <objc/runtime.h>
#import "NTFSpringBoard.h"
#import "NTFPreferences.h"
#import "NTFDotView.h"
#import "NTFColorExtractor.h"

#if DEBUG
static void NTFLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void NTFLog(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	NSLog(@"[ntfy] %@", line);
	NSString *path = @"/var/mobile/Library/Caches/ntfy-debug.log";
	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
	if (!handle) {
		[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
		handle = [NSFileHandle fileHandleForWritingAtPath:path];
	}
	[handle seekToEndOfFile];
	[handle writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[handle closeFile];
}
#endif

@interface NTFWeakBox : NSObject
@property (nonatomic, weak) id object;
@end

@implementation NTFWeakBox
@end

static const void *kNTFDotKey = &kNTFDotKey;
static const void *kNTFHiddenViewsKey = &kNTFHiddenViewsKey;
static const void *kNTFIconKey = &kNTFIconKey;
static const void *kNTFNeedsColorKey = &kNTFNeedsColorKey;

static NSHashTable<UIView *> *ntfBadgeViews;
static NSMapTable<UIImage *, UIColor *> *ntfImageColors;
static NSMutableDictionary<NSString *, id> *ntfLeafColors;
static NSMutableDictionary<NSString *, id> *ntfBundleColors;
static Class ntfIconViewClass;
static Class ntfBadgeViewClass;

#pragma mark - Associated state

static NTFDotView *NTFDotForBadge(UIView *badge) {
	return objc_getAssociatedObject(badge, kNTFDotKey);
}

static SBIcon *NTFIconForBadge(UIView *badge) {
	return [objc_getAssociatedObject(badge, kNTFIconKey) object];
}

static void NTFSetIconForBadge(UIView *badge, id icon) {
	NTFWeakBox *box = nil;
	if (icon) {
		box = [NTFWeakBox new];
		box.object = icon;
	}
	objc_setAssociatedObject(badge, kNTFIconKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSHashTable<UIView *> *NTFHiddenViews(UIView *badge, BOOL create) {
	NSHashTable *table = objc_getAssociatedObject(badge, kNTFHiddenViewsKey);
	if (!table && create) {
		table = [NSHashTable weakObjectsHashTable];
		objc_setAssociatedObject(badge, kNTFHiddenViewsKey, table, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return table;
}

#pragma mark - SpringBoard helpers

static SBIconView *NTFIconViewForBadge(UIView *badge) {
	UIView *view = badge.superview;
	for (NSUInteger depth = 0; view && depth < 4; depth++, view = view.superview) {
		if ([view isKindOfClass:ntfIconViewClass]) return (SBIconView *)view;
	}
	return nil;
}

static BOOL NTFIconIsFolder(SBIcon *icon) {
	return [icon respondsToSelector:@selector(folder)];
}

static BOOL NTFIconHasBadge(SBIcon *icon) {
	if (![icon respondsToSelector:@selector(badgeNumberOrString)]) return NO;
	id badge = [icon badgeNumberOrString];
	if ([badge isKindOfClass:[NSNumber class]]) return [badge integerValue] > 0;
	if ([badge isKindOfClass:[NSString class]]) return [badge length] > 0;
	return NO;
}

static NSString *NTFIdentifier(SBIcon *icon) {
	return [icon respondsToSelector:@selector(uniqueIdentifier)] ? [icon uniqueIdentifier] : nil;
}

static UIImage *NTFDisplayedIconImage(SBIconView *iconView) {
	if (![iconView respondsToSelector:@selector(_iconImageView)]) return nil;
	SBIconImageView *imageView = [iconView _iconImageView];
	if ([imageView respondsToSelector:@selector(displayedImage)]) return [imageView displayedImage];
	if ([imageView respondsToSelector:@selector(contentsImage)]) return [imageView contentsImage];
	return nil;
}

static CGRect NTFIconImageFrame(SBIconView *iconView) {
	CGRect frame = CGRectNull;
	if ([iconView respondsToSelector:@selector(iconImageFrame)]) {
		frame = [iconView iconImageFrame];
	} else if ([iconView respondsToSelector:@selector(_iconImageView)]) {
		frame = [iconView _iconImageView].frame;
	}
	if (CGRectIsNull(frame) || CGRectIsEmpty(frame)) {
		CGFloat side = CGRectGetWidth(iconView.bounds);
		frame = CGRectMake(0, 0, side, side);
	}
	return frame;
}

#pragma mark - Adaptive colour

static id NTFCacheValue(UIColor *color) {
	return color ?: (id)[NSNull null];
}

static UIColor *NTFColorFromCacheValue(id value) {
	return [value isKindOfClass:[UIColor class]] ? value : nil;
}

static UIColor *NTFColorForImage(UIImage *image) {
	if (!image) return nil;
	id cached = [ntfImageColors objectForKey:image];
	if (cached) return NTFColorFromCacheValue(cached);
	UIColor *color = NTFRepresentativeColor(image);
	[ntfImageColors setObject:NTFCacheValue(color) forKey:image];
	return color;
}

static UIColor *NTFBundleIconColor(SBIcon *icon) {
	if (![icon respondsToSelector:@selector(applicationBundleID)]) return nil;
	NSString *bundleID = [(SBLeafIcon *)icon applicationBundleID];
	if (!bundleID.length) return nil;

	id cached = ntfBundleColors[bundleID];
	if (cached) return NTFColorFromCacheValue(cached);

	UIImage *image = nil;
	if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
		image = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:UIScreen.mainScreen.scale];
	}
	UIColor *color = NTFRepresentativeColor(image);
	ntfBundleColors[bundleID] = NTFCacheValue(color);
	return color;
}

static UIColor *NTFLeafColor(SBIcon *icon, SBIconView *iconView) {
	NSString *identifier = NTFIdentifier(icon);
	UIImage *image = iconView ? NTFDisplayedIconImage(iconView) : nil;
	if (image) {
		UIColor *color = NTFColorForImage(image);
		if (identifier) ntfLeafColors[identifier] = NTFCacheValue(color);
		return color;
	}
	id cached = identifier ? ntfLeafColors[identifier] : nil;
	if (cached) return NTFColorFromCacheValue(cached);
	return NTFBundleIconColor(icon);
}

static UIColor *NTFFolderColor(SBFolderIcon *folderIcon) {
	SBFolder *folder = [folderIcon folder];
	if (![folder respondsToSelector:@selector(leafIcons)]) return nil;

	NSMutableArray<SBIcon *> *badged = [NSMutableArray array];
	for (SBIcon *icon in [folder leafIcons]) {
		if (NTFIconHasBadge(icon)) [badged addObject:icon];
	}
	[badged sortUsingComparator:^NSComparisonResult(SBIcon *a, SBIcon *b) {
		return [NTFIdentifier(a) ?: @"" compare:NTFIdentifier(b) ?: @""];
	}];

	NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:badged.count];
	for (SBIcon *icon in badged) {
		UIColor *color = NTFLeafColor(icon, nil);
		if (color) [colors addObject:color];
	}
	return NTFDominantColorAmong(colors);
}

static UIColor *NTFResolvedColor(SBIcon *icon, SBIconView *iconView) {
	NTFPreferences *prefs = [NTFPreferences shared];
	UIColor *color = nil;
	if (prefs.adaptive && icon) {
		color = NTFIconIsFolder(icon) ? NTFFolderColor((SBFolderIcon *)icon) : NTFLeafColor(icon, iconView);
	}
	if (!color) color = prefs.color;
	return prefs.pastel ? NTFPastelColor(color) : color;
}

#pragma mark - Dot management

static void NTFHideStockView(UIView *badge, UIView *view) {
	if (view.hidden || view == NTFDotForBadge(badge)) return;
	view.hidden = YES;
	[NTFHiddenViews(badge, YES) addObject:view];
}

static void NTFPositionDot(UIView *badge, NTFDotView *dot, SBIconView *iconView) {
	NTFPreferences *prefs = [NTFPreferences shared];
	CGFloat scale = badge.window.screen.scale ?: UIScreen.mainScreen.scale;
	CGRect frame;

	if (iconView && badge.superview) {
		CGRect imageFrame = NTFIconImageFrame(iconView);
		CGFloat unit = CGRectGetWidth(imageFrame) / 60.0;
		if (unit <= 0) unit = 1;
		CGFloat diameter = MAX(round(prefs.size * unit * scale) / scale, 2.0 / scale);
		CGFloat centerX = CGRectGetMaxX(imageFrame) + (prefs.offsetX - 2.0) * unit;
		CGFloat centerY = CGRectGetMinY(imageFrame) + (2.0 - prefs.offsetY) * unit;
		CGPoint origin = CGPointMake(round((centerX - diameter / 2.0) * scale) / scale,
		                             round((centerY - diameter / 2.0) * scale) / scale);

		// ignore the badge transform so the dot follows the zoom animation
		CGPoint inSuperview = [iconView convertPoint:origin toView:badge.superview];
		CGRect bounds = badge.bounds;
		CGPoint anchor = badge.layer.anchorPoint;
		CGPoint center = badge.center;
		frame = CGRectMake(inSuperview.x - (center.x - bounds.size.width * anchor.x) + bounds.origin.x,
		                   inSuperview.y - (center.y - bounds.size.height * anchor.y) + bounds.origin.y,
		                   diameter, diameter);
	} else {
		CGFloat diameter = round(prefs.size * scale) / scale;
		frame = CGRectMake(CGRectGetMidX(badge.bounds) - diameter / 2.0,
		                   CGRectGetMidY(badge.bounds) - diameter / 2.0,
		                   diameter, diameter);
	}

	if (!CGRectEqualToRect(dot.frame, frame)) dot.frame = frame;
}

static void NTFRestoreBadge(UIView *badge) {
	NTFDotView *dot = NTFDotForBadge(badge);
	if (dot) {
		[dot removeFromSuperview];
		objc_setAssociatedObject(badge, kNTFDotKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	NSHashTable<UIView *> *hidden = NTFHiddenViews(badge, NO);
	for (UIView *view in hidden.allObjects) {
		if (view.superview == badge) view.hidden = NO;
	}
	[hidden removeAllObjects];
}

static void NTFApplyBadge(UIView *badge, BOOL refreshAppearance) {
	NTFPreferences *prefs = [NTFPreferences shared];
	if (!prefs.enabled) {
		NTFRestoreBadge(badge);
		return;
	}

	NTFDotView *dot = NTFDotForBadge(badge);
	if (!dot) {
		dot = [[NTFDotView alloc] initWithFrame:CGRectZero];
		objc_setAssociatedObject(badge, kNTFDotKey, dot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		refreshAppearance = YES;
	}
	if (dot.superview != badge) [badge addSubview:dot];
	if (badge.subviews.lastObject != dot) [badge bringSubviewToFront:dot];

	for (UIView *view in badge.subviews) NTFHideStockView(badge, view);

	SBIconView *iconView = NTFIconViewForBadge(badge);
	BOOL needsColor = [objc_getAssociatedObject(badge, kNTFNeedsColorKey) boolValue];
	if (refreshAppearance || (needsColor && iconView)) {
		SBIcon *icon = NTFIconForBadge(badge);
		[dot applyStyle:prefs.style color:NTFResolvedColor(icon, iconView) border:prefs.border opacity:prefs.opacity];
		// no icon view yet, retry once the badge is on screen
		BOOL pending = prefs.adaptive && !iconView && icon && !NTFIconIsFolder(icon);
		objc_setAssociatedObject(badge, kNTFNeedsColorKey, pending ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	NTFPositionDot(badge, dot, iconView);
}

static void NTFConfigureBadge(UIView *badge, id icon) {
#if DEBUG
	NSMutableArray *subviews = [NSMutableArray array];
	for (UIView *view in badge.subviews) [subviews addObject:NSStringFromClass([view class])];
	NTFLog(@"configure %@ badge=%@ superview=%@ iconView=%d subviews=%@", NTFIdentifier(icon), [icon badgeNumberOrString],
	      NSStringFromClass([badge.superview class]), NTFIconViewForBadge(badge) != nil, subviews);
#endif
	[ntfBadgeViews addObject:badge];
	NTFSetIconForBadge(badge, icon);
	NTFApplyBadge(badge, YES);
}

static void NTFPreferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NTFPreferences shared] reload];
		for (UIView *badge in ntfBadgeViews.allObjects) NTFApplyBadge(badge, YES);
	});
}

#pragma mark - Hooks

%hook SBIconBadgeView

- (void)configureForIcon:(id)icon infoProvider:(id)provider {
	%orig;
	NTFConfigureBadge(self, icon);
}

- (void)configureAnimatedForIcon:(id)icon infoProvider:(id)provider animator:(id)animator {
	%orig;
	NTFConfigureBadge(self, icon);
}

- (void)prepareForReuse {
	%orig;
	NTFSetIconForBadge(self, nil);
}

- (void)layoutSubviews {
	%orig;
	if ([NTFPreferences shared].enabled) NTFApplyBadge(self, NO);
}

- (void)didAddSubview:(UIView *)subview {
	%orig;
	if ([NTFPreferences shared].enabled && NTFDotForBadge(self)) NTFHideStockView(self, subview);
}

%end

%hook SBIconView

- (void)layoutSubviews {
	%orig;
	if (![NTFPreferences shared].enabled) return;
	for (UIView *subview in self.subviews) {
		if ([subview isKindOfClass:ntfBadgeViewClass] && NTFDotForBadge(subview)) {
			NTFApplyBadge(subview, NO);
		}
	}
}

%end

%ctor {
	@autoreleasepool {
		ntfIconViewClass = objc_getClass("SBIconView");
		ntfBadgeViewClass = objc_getClass("SBIconBadgeView");
		if (!ntfIconViewClass || !ntfBadgeViewClass) return;

		ntfBadgeViews = [NSHashTable weakObjectsHashTable];
		ntfImageColors = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
		                                           valueOptions:NSPointerFunctionsStrongMemory
		                                               capacity:64];
		ntfLeafColors = [NSMutableDictionary dictionary];
		ntfBundleColors = [NSMutableDictionary dictionary];
		[NTFPreferences shared];

		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, NTFPreferencesChanged,
		                                CFSTR(NTF_NOTIFICATION), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		%init;

#if DEBUG
		NTFLog(@"loaded: configure=%d animated=%d reuse=%d iconImageFrame=%d iconImageView=%d displayedImage=%d leafIcons=%d bundleIcon=%d",
		      [ntfBadgeViewClass instancesRespondToSelector:@selector(configureForIcon:infoProvider:)],
		      [ntfBadgeViewClass instancesRespondToSelector:@selector(configureAnimatedForIcon:infoProvider:animator:)],
		      [ntfBadgeViewClass instancesRespondToSelector:@selector(prepareForReuse)],
		      [ntfIconViewClass instancesRespondToSelector:@selector(iconImageFrame)],
		      [ntfIconViewClass instancesRespondToSelector:@selector(_iconImageView)],
		      [objc_getClass("SBIconImageView") instancesRespondToSelector:@selector(displayedImage)],
		      [objc_getClass("SBFolder") instancesRespondToSelector:@selector(leafIcons)],
		      [UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]);
#endif
	}
}
