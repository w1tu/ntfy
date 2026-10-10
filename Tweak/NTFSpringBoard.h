#import <UIKit/UIKit.h>

// checked against springboardhome headers, optional stuff goes through respondsToSelector:

@interface SBIcon : NSObject
- (NSString *)uniqueIdentifier;
- (id)badgeNumberOrString;
- (BOOL)isFolderIcon;
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

@class SBIconView;

@interface SBIconImageView : UIView
- (UIImage *)displayedImage;
- (UIImage *)contentsImage;
- (SBIcon *)icon;
- (SBIconView *)iconView;
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
- (void)_configureBackgroundAfterIconImageAppearanceChange; // ios 18
- (void)_configureAfterIconImageAppearanceChange;           // ios 26
@end

@interface UIImage (NTFPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end
