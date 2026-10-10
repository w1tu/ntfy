#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>
#import "../Shared/NTFShared.h"

// keys: label, min, max, ntfStep, ntfFormat, ntfHollowOnly
@interface NTFSliderCell : PSTableCell
@end

@implementation NTFSliderCell {
	UILabel *_titleLabel;
	UILabel *_valueLabel;
	UISlider *_slider;
	double _savedValue;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;

		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
		_titleLabel.adjustsFontForContentSizeCategory = YES;
		_titleLabel.isAccessibilityElement = NO;
		[self.contentView addSubview:_titleLabel];

		_valueLabel = [UILabel new];
		_valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize weight:UIFontWeightRegular];
		_valueLabel.textColor = UIColor.secondaryLabelColor;
		_valueLabel.textAlignment = NSTextAlignmentRight;
		_valueLabel.isAccessibilityElement = NO;
		[self.contentView addSubview:_valueLabel];

		_slider = [UISlider new];
		[_slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
		[_slider addTarget:self action:@selector(sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
		[self.contentView addSubview:_slider];

		[self configureWithSpecifier:specifier];
	}
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];
	[self configureWithSpecifier:specifier];
}

- (void)setValue:(id)value {
	// value label is drawn by the cell
}

- (void)configureWithSpecifier:(PSSpecifier *)specifier {
	self.textLabel.text = nil;
	self.detailTextLabel.text = nil;
	_titleLabel.text = specifier.name;
	_slider.accessibilityLabel = specifier.name;
	_slider.minimumValue = [[specifier propertyForKey:@"min"] floatValue];
	_slider.maximumValue = [[specifier propertyForKey:@"max"] floatValue];

	PSListController *controller = (PSListController *)specifier.target;
	id value = [controller respondsToSelector:@selector(readPreferenceValue:)] ? [controller readPreferenceValue:specifier] : nil;
	_savedValue = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : [[specifier propertyForKey:@"default"] doubleValue];
	_slider.value = _savedValue;
	[self updateValueLabel:_savedValue];

	BOOL enabled = YES;
	if ([[specifier propertyForKey:@"ntfHollowOnly"] boolValue]) {
		enabled = [NTFCopyPreference(NTF_KEY_STYLE) integerValue] == NTFDotStyleHollow;
	}
	_slider.enabled = enabled;
	_titleLabel.textColor = enabled ? UIColor.labelColor : UIColor.tertiaryLabelColor;
	_valueLabel.textColor = enabled ? UIColor.secondaryLabelColor : UIColor.tertiaryLabelColor;
}

- (double)step {
	double step = [[self.specifier propertyForKey:@"ntfStep"] doubleValue];
	return step > 0 ? step : 1.0;
}

- (double)snapped:(double)value {
	return round(value / [self step]) * [self step];
}

- (NSString *)formattedValue:(double)value {
	NSString *format = [self.specifier propertyForKey:@"ntfFormat"] ?: @"%.0f";
	if (fabs(value) < 0.001) {
		value = 0;
		format = [format stringByReplacingOccurrencesOfString:@"%+" withString:@"%"];
	}
	return [NSString stringWithFormat:format, value];
}

// fits the widest value so it doesn't jump around
- (CGFloat)valueLabelWidth {
	NSDictionary *attributes = @{NSFontAttributeName: _valueLabel.font};
	CGFloat width = 0;
	for (NSNumber *value in @[@(_slider.minimumValue), @(_slider.maximumValue)]) {
		width = MAX(width, [[self formattedValue:value.doubleValue] sizeWithAttributes:attributes].width);
	}
	return ceil(width) + 2;
}

- (void)updateValueLabel:(double)value {
	NSString *text = [self formattedValue:value];
	_valueLabel.text = text;
	_slider.accessibilityValue = text;
}

- (void)sliderChanged:(UISlider *)slider {
	double value = [self snapped:slider.value];
	[self updateValueLabel:value];
	if (value == _savedValue) return;
	_savedValue = value;
	PSListController *controller = (PSListController *)self.specifier.target;
	if ([controller respondsToSelector:@selector(setPreferenceValue:specifier:)]) {
		[controller setPreferenceValue:@(value) specifier:self.specifier];
	}
}

- (void)sliderEnded:(UISlider *)slider {
	[slider setValue:[self snapped:slider.value] animated:YES];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect area = UIEdgeInsetsInsetRect(self.contentView.bounds, self.contentView.layoutMargins);
	CGFloat lineHeight = ceil(_titleLabel.font.lineHeight);
	CGFloat valueWidth = [self valueLabelWidth];
	CGFloat sliderHeight = 31;
	CGFloat contentHeight = lineHeight + sliderHeight;
	CGFloat top = MAX(6, round((CGRectGetHeight(self.contentView.bounds) - contentHeight) / 2.0));

	_valueLabel.frame = CGRectMake(CGRectGetMaxX(area) - valueWidth, top, valueWidth, lineHeight);
	_titleLabel.frame = CGRectMake(CGRectGetMinX(area), top, CGRectGetWidth(area) - valueWidth - 8, lineHeight);
	_slider.frame = CGRectMake(CGRectGetMinX(area), top + lineHeight, CGRectGetWidth(area), sliderHeight);
}

@end
