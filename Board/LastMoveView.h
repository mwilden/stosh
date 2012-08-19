#include "square.h"

using namespace Chess;

@interface LastMoveView : UIView {
   Square square1, square2;
   float squareSize;
}

- (id)initWithFrame:(CGRect)frame fromSquare:(Square)fs toSquare:(Square)ts;

@end
