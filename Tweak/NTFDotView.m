#import "NTFDotView.h"

@implementation NTFDotView {
	NTFDotStyle _style;
	UIColor *_color;
	CGFloat _border;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.userInteractionEnabled = NO;
		self.isAccessibilityElement = NO;
		self.layer.masksToBounds = YES;
		self.layer.cornerCurve = kCACornerCurveCircular;
	}
	return self;
}

- (void)applyStyle:(NTFDotStyle)style color:(UIColor *)color border:(CGFloat)border opacity:(CGFloat)opacity {
	_style = style;
	_color = color;
	_border = border;
	if (self.alpha != opacity) self.alpha = opacity;
	[self updateAppearance];
}

- (void)setBounds:(CGRect)bounds {
	BOOL sizeChanged = !CGSizeEqualToSize(bounds.size, self.bounds.size);
	[super setBounds:bounds];
	if (sizeChanged) [self updateAppearance];
}

- (void)setFrame:(CGRect)frame {
	BOOL sizeChanged = !CGSizeEqualToSize(frame.size, self.bounds.size);
	[super setFrame:frame];
	if (sizeChanged) [self updateAppearance];
}

- (void)updateAppearance {
	CGFloat diameter = MIN(self.bounds.size.width, self.bounds.size.height);
	self.layer.cornerRadius = diameter / 2.0;

	if (_style == NTFDotStyleHollow) {
		CGFloat scale = UIScreen.mainScreen.scale;
		CGFloat border = MAX(round(_border * scale) / scale, 1.0 / scale);
		self.backgroundColor = UIColor.clearColor;
		self.layer.borderWidth = MIN(border, diameter / 2.0);
		self.layer.borderColor = _color.CGColor;
	} else {
		self.backgroundColor = _color;
		self.layer.borderWidth = 0;
		self.layer.borderColor = nil;
	}
}

@end
