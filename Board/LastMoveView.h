#include "move.h"

using namespace Chess;

@interface LastMoveView : UIView {
   Move move;
   int squareSize;
}

- (id)initWithFrame:(CGRect)frame fromSquare:(Square)fs toSquare:(Square)ts;

@end
