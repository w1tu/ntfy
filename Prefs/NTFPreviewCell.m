#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#import "../Shared/NTFShared.h"
#import "../Tweak/NTFDotView.h"
#import "../Tweak/NTFColorExtractor.h"

NSString *const NTFPreviewNeedsUpdateNotification = @"NTFPreviewNeedsUpdateNotification";

#define NTF_PREVIEW_ICON_SIZE 60.0
#define NTF_PREVIEW_SPACING 30.0

@interface UIImage (NTFPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface NTFPreviewCell : PSTableCell
@end

@implementation NTFPreviewCell {
	NSArray<UIImageView *> *_icons;
	NSArray<NTFDotView *> *_dots;
	NSArray<UIColor *> *_iconColors;
}

+ (NSArray<NSString *> *)sampleBundleIdentifiers {
	return @[@"com.apple.MobileSMS", @"com.apple.mobilemail", @"com.apple.mobilephone"];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.isAccessibilityElement = YES;
		self.accessibilityLabel = @"Preview";

		NSMutableArray *icons = [NSMutableArray array];
		NSMutableArray *dots = [NSMutableArray array];
		NSMutableArray *colors = [NSMutableArray array];
		CGFloat scale = UIScreen.mainScreen.scale;
		for (NSString *bundleID in [[self class] sampleBundleIdentifiers]) {
			UIImage *image = nil;
			if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
				image = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:scale];
			}
			UIImageView *icon = [[UIImageView alloc] initWithImage:image];
			icon.contentMode = UIViewContentModeScaleAspectFit;
			[self.contentView addSubview:icon];
			[icons addObject:icon];

			NTFDotView *dot = [[NTFDotView alloc] initWithFrame:CGRectZero];
			[self.contentView addSubview:dot];
			[dots addObject:dot];

			[colors addObject:NTFRepresentativeColor(image) ?: (id)[NSNull null]];
		}
		_icons = icons;
		_dots = dots;
		_iconColors = colors;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePreview) name:NTFPreviewNeedsUpdateNotification object:nil];
		[self updatePreview];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];
	self.textLabel.text = nil;
	[self updatePreview];
}

- (void)setValue:(id)value {
}

- (void)updatePreview {
	BOOL enabled = [NTFCopyPreference(NTF_KEY_ENABLED) boolValue];
	NTFDotStyle style = [NTFCopyPreference(NTF_KEY_STYLE) integerValue] == NTFDotStyleHollow ? NTFDotStyleHollow : NTFDotStyleFilled;
	UIColor *selected = NTFColorFromHex(NTFCopyPreference(NTF_KEY_COLOR)) ?: UIColor.systemRedColor;
	BOOL adaptive = [NTFCopyPreference(NTF_KEY_ADAPTIVE) boolValue];
	BOOL pastel = [NTFCopyPreference(NTF_KEY_PASTEL) boolValue];
	CGFloat border = [NTFCopyPreference(NTF_KEY_BORDER) doubleValue];
	CGFloat opacity = [NTFCopyPreference(NTF_KEY_OPACITY) doubleValue] / 100.0;

	for (NSUInteger i = 0; i < _dots.count; i++) {
		UIColor *color = adaptive && [_iconColors[i] isKindOfClass:[UIColor class]] ? _iconColors[i] : selected;
		if (pastel) color = NTFPastelColor(color);
		[_dots[i] applyStyle:style color:color border:border opacity:opacity];
		_dots[i].hidden = !enabled;
	}
	self.accessibilityValue = enabled ? @"Dots shown on sample icons" : @"ntfy is turned off";
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat size = [NTFCopyPreference(NTF_KEY_SIZE) doubleValue];
	CGFloat offsetX = [NTFCopyPreference(NTF_KEY_OFFSET_X) doubleValue];
	CGFloat offsetY = [NTFCopyPreference(NTF_KEY_OFFSET_Y) doubleValue];
	CGFloat scale = self.window.screen.scale ?: UIScreen.mainScreen.scale;

	CGRect bounds = self.contentView.bounds;
	CGFloat totalWidth = _icons.count * NTF_PREVIEW_ICON_SIZE + (_icons.count - 1) * NTF_PREVIEW_SPACING;
	CGFloat x = round((CGRectGetWidth(bounds) - totalWidth) / 2.0);
	CGFloat y = round((CGRectGetHeight(bounds) - NTF_PREVIEW_ICON_SIZE) / 2.0);

	for (NSUInteger i = 0; i < _icons.count; i++) {
		CGRect iconFrame = CGRectMake(x + i * (NTF_PREVIEW_ICON_SIZE + NTF_PREVIEW_SPACING), y, NTF_PREVIEW_ICON_SIZE, NTF_PREVIEW_ICON_SIZE);
		_icons[i].frame = iconFrame;
		_dots[i].frame = NTFDotFrame(iconFrame, size, offsetX, offsetY, scale);
	}
}

@end
