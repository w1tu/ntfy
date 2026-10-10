#import <UIKit/UIKit.h>

// main accent colour of an icon, nil if it's only black/white/transparent
UIColor *NTFRepresentativeColor(UIImage *image);

// most common hue among the colours
UIColor *NTFDominantColorAmong(NSArray<UIColor *> *colors);

UIColor *NTFPastelColor(UIColor *color);
