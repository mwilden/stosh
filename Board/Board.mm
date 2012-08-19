#import "Board.h"

static UIColor *darkSquareColor = [[UIColor colorWithRed: 0.20 green: 0.40 blue: 0.70 alpha: 1.0] retain];
static UIColor *lightSquareColor = [[UIColor colorWithRed: 0.69 green: 0.78 blue: 1.0 alpha: 1.0] retain];
static UIColor *highlightColor = [[UIColor purpleColor] retain];

@implementation Board

+ (UIColor*)darkSquareColor {
    return darkSquareColor;
}

+ (UIColor*)lightSquareColor {
    return lightSquareColor;
}

+ (UIColor*)highlightColor {
    return highlightColor;
}

@end
