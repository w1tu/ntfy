#import "../Shared/NTFShared.h"

@interface NTFPreferences : NSObject
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) NTFDotStyle style;
@property (nonatomic, readonly, strong) UIColor *color;
@property (nonatomic, readonly) BOOL adaptive;
@property (nonatomic, readonly) BOOL pastel;
@property (nonatomic, readonly) CGFloat size;
@property (nonatomic, readonly) CGFloat border;
@property (nonatomic, readonly) CGFloat opacity;
@property (nonatomic, readonly) CGFloat offsetX;
@property (nonatomic, readonly) CGFloat offsetY;

+ (instancetype)shared;
- (void)reload;
@end
