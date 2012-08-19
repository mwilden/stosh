#import "Board.h"

@implementation Board

+ (UIColor*)darkSquareColor {
    return [UIColor colorWithRed: 0.20 green: 0.40 blue: 0.70 alpha: 1.0];
}

+ (UIColor*)lightSquareColor {
    return [UIColor colorWithRed: 0.69 green: 0.78 blue: 1.0 alpha: 1.0];
}

+ (UIColor*)highlightColor {
    return [UIColor purpleColor];
}

@end
