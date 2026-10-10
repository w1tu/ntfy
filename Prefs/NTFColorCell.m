#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>
#import "../Shared/NTFShared.h"

#define NTF_SWATCH_SIZE 34.0
#define NTF_SWATCH_COLUMNS 7
#define NTF_SWATCH_ROW_SPACING 12.0

@interface NTFSwatchButton : UIButton
@property (nonatomic, strong) UIColor *swatchColor;
@property (nonatomic, assign) BOOL isCustom;
@end

@implementation NTFSwatchButton {
	CALayer *_fillLayer;
	CAGradientLayer *_spectrumLayer;
	CAShapeLayer *_ringLayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_ringLayer = [CAShapeLayer layer];
		_ringLayer.fillColor = UIColor.clearColor.CGColor;
		_ringLayer.lineWidth = 2.0;
		_ringLayer.hidden = YES;
		[self.layer addSublayer:_ringLayer];

		_fillLayer = [CALayer layer];
		_fillLayer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
		[self.layer addSublayer:_fillLayer];
		self.isAccessibilityElement = YES;
	}
	return self;
}

- (void)setIsCustom:(BOOL)isCustom {
	_isCustom = isCustom;
	if (isCustom && !_spectrumLayer) {
		_spectrumLayer = [CAGradientLayer layer];
		_spectrumLayer.type = kCAGradientLayerConic;
		_spectrumLayer.startPoint = CGPointMake(0.5, 0.5);
		_spectrumLayer.endPoint = CGPointMake(0.5, 0);
		NSMutableArray *colors = [NSMutableArray array];
		for (NSInteger i = 0; i <= 12; i++) {
			[colors addObject:(id)[UIColor colorWithHue:i / 12.0 saturation:0.85 brightness:1 alpha:1].CGColor];
		}
		_spectrumLayer.colors = colors;
		[self.layer insertSublayer:_spectrumLayer below:_fillLayer];
	}
	[self setNeedsLayout];
}

- (void)setSelected:(BOOL)selected {
	[super setSelected:selected];
	_ringLayer.hidden = !selected;
	self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
	[self setNeedsLayout];
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	self.alpha = highlighted ? 0.6 : 1.0;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.bounds;
	CGFloat side = MIN(bounds.size.width, bounds.size.height);
	CGRect square = CGRectMake((bounds.size.width - side) / 2.0, (bounds.size.height - side) / 2.0, side, side);

	_ringLayer.frame = square;
	_ringLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(CGRectMake(0, 0, side, side), 1, 1)].CGPath;
	_ringLayer.strokeColor = [UIColor.labelColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;

	CGRect inner = CGRectInset(square, 5, 5);
	_fillLayer.borderColor = [UIColor.separatorColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
	if (_isCustom) {
		_spectrumLayer.frame = inner;
		_spectrumLayer.cornerRadius = inner.size.width / 2.0;
		CGRect center = CGRectInset(inner, inner.size.width * 0.27, inner.size.width * 0.27);
		_fillLayer.frame = center;
		_fillLayer.cornerRadius = center.size.width / 2.0;
		_fillLayer.backgroundColor = (self.selected && _swatchColor ? _swatchColor : UIColor.whiteColor).CGColor;
	} else {
		_fillLayer.frame = inner;
		_fillLayer.cornerRadius = inner.size.width / 2.0;
		_fillLayer.backgroundColor = _swatchColor.CGColor;
	}
}

@end

@interface NTFColorCell : PSTableCell <UIColorPickerViewControllerDelegate>
@end

@implementation NTFColorCell {
	NSArray<NTFSwatchButton *> *_swatches;
	NTFSwatchButton *_customSwatch;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.textLabel.text = nil;

		NSMutableArray *swatches = [NSMutableArray array];
		NSArray<NSString *> *hexes = NTFPresetColors();
		NSArray<NSString *> *names = NTFPresetColorNames();
		for (NSUInteger i = 0; i < hexes.count; i++) {
			NTFSwatchButton *swatch = [NTFSwatchButton buttonWithType:UIButtonTypeCustom];
			swatch.swatchColor = NTFColorFromHex(hexes[i]);
			swatch.accessibilityLabel = names[i];
			swatch.tag = (NSInteger)i;
			[swatch addTarget:self action:@selector(presetTapped:) forControlEvents:UIControlEventTouchUpInside];
			[self.contentView addSubview:swatch];
			[swatches addObject:swatch];
		}

		_customSwatch = [NTFSwatchButton buttonWithType:UIButtonTypeCustom];
		_customSwatch.isCustom = YES;
		_customSwatch.accessibilityLabel = @"Custom Colour";
		_customSwatch.accessibilityHint = @"Opens the colour picker";
		[_customSwatch addTarget:self action:@selector(customTapped:) forControlEvents:UIControlEventTouchUpInside];
		[self.contentView addSubview:_customSwatch];
		[swatches addObject:_customSwatch];

		_swatches = swatches;
		[self refreshSelection];
	}
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];
	self.textLabel.text = nil;
	self.detailTextLabel.text = nil;
	[self refreshSelection];
}

- (void)setValue:(id)value {
	// don't show the hex value
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect area = UIEdgeInsetsInsetRect(self.contentView.bounds, self.contentView.layoutMargins);
	CGFloat spacing = (CGRectGetWidth(area) - NTF_SWATCH_COLUMNS * NTF_SWATCH_SIZE) / (NTF_SWATCH_COLUMNS - 1);
	NSUInteger rows = (_swatches.count + NTF_SWATCH_COLUMNS - 1) / NTF_SWATCH_COLUMNS;
	CGFloat gridHeight = rows * NTF_SWATCH_SIZE + (rows - 1) * NTF_SWATCH_ROW_SPACING;
	CGFloat top = round((CGRectGetHeight(self.contentView.bounds) - gridHeight) / 2.0);

	for (NSUInteger i = 0; i < _swatches.count; i++) {
		NSUInteger row = i / NTF_SWATCH_COLUMNS;
		NSUInteger column = i % NTF_SWATCH_COLUMNS;
		_swatches[i].frame = CGRectMake(round(CGRectGetMinX(area) + column * (NTF_SWATCH_SIZE + spacing)),
		                                top + row * (NTF_SWATCH_SIZE + NTF_SWATCH_ROW_SPACING),
		                                NTF_SWATCH_SIZE, NTF_SWATCH_SIZE);
	}
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
	[super traitCollectionDidChange:previousTraitCollection];
	for (UIView *swatch in _swatches) [swatch setNeedsLayout];
}

- (NSString *)currentHex {
	return [NTFCopyPreference(NTF_KEY_COLOR) uppercaseString];
}

- (void)refreshSelection {
	NSString *current = [self currentHex];
	NSArray<NSString *> *hexes = NTFPresetColors();
	BOOL matchedPreset = NO;
	for (NTFSwatchButton *swatch in _swatches) {
		if (swatch == _customSwatch) continue;
		swatch.selected = [hexes[(NSUInteger)swatch.tag] isEqualToString:current];
		matchedPreset |= swatch.selected;
	}
	_customSwatch.swatchColor = NTFColorFromHex(current);
	_customSwatch.selected = !matchedPreset;
	_customSwatch.accessibilityValue = matchedPreset ? nil : current;
}

- (void)saveHex:(NSString *)hex {
	if (!hex.length) return;
	PSListController *controller = (PSListController *)self.specifier.target;
	if ([controller respondsToSelector:@selector(setPreferenceValue:specifier:)]) {
		[controller setPreferenceValue:hex specifier:self.specifier];
	}
	[self refreshSelection];
}

- (void)presetTapped:(NTFSwatchButton *)sender {
	[self saveHex:NTFPresetColors()[(NSUInteger)sender.tag]];
}

- (void)customTapped:(NTFSwatchButton *)sender {
	UIViewController *host = (UIViewController *)self.specifier.target;
	if (![host isKindOfClass:[UIViewController class]]) return;
	UIColorPickerViewController *picker = [UIColorPickerViewController new];
	picker.supportsAlpha = NO;
	picker.selectedColor = NTFColorFromHex([self currentHex]) ?: UIColor.redColor;
	picker.delegate = self;
	[host presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)picker didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
	if (!continuously) [self saveHex:NTFHexFromColor(color)];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {
	[self saveHex:NTFHexFromColor(picker.selectedColor)];
}

@end
