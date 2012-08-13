#import <UIKit/UIKit.h>

#include "../Chess/square.h"

using namespace Chess;

@interface LastMoveView : UIView {
   Square square1, square2;
   float sqSize;
}

- (id)initWithFrame:(CGRect)frame fromSq:(Square)fSq toSq:(Square)tSq;

@end
