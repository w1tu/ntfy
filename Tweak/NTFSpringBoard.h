#import <UIKit/UIKit.h>

// checked against springboardhome headers, optional stuff goes through respondsToSelector:

@interface SBIcon : NSObject
- (NSString *)uniqueIdentifier;
- (id)badgeNumberOrString;
@end

@interface SBLeafIcon : SBIcon
- (NSString *)applicationBundleID;
@end

@interface SBFolder : NSObject
- (id)leafIcons;
@end

@interface SBFolderIcon : SBIcon
- (SBFolder *)folder;
@end

@interface SBIconImageView : UIView
- (UIImage *)displayedImage;
- (UIImage *)contentsImage;
@end

@interface SBIconView : UIView
- (SBIcon *)icon;
- (CGRect)iconImageFrame;
- (SBIconImageView *)_iconImageView;
@end

@interface SBIconBadgeView : UIView
- (void)configureForIcon:(id)icon infoProvider:(id)provider;
- (void)configureAnimatedForIcon:(id)icon infoProvider:(id)provider animator:(id)animator;
- (void)prepareForReuse;
@end

@interface UIImage (NTFPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end
