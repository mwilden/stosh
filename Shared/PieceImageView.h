#include "square.h"

using namespace Chess;

@class BoardView;
@class GameController;

@interface PieceImageView : UIImageView {
   GameController *gameController;
   BoardView *boardView;
   Square square;
   CGRect oldFrame;
   CGPoint location;
   BOOL isBeingDragged;
   BOOL wasDraggedAwayFromSquare;
   float squareSize;
}

@property (nonatomic, assign) CGPoint location;
@property (nonatomic, readonly) Square square;

- (id)initWithFrame:(CGRect)frame
     gameController:(GameController *)controller
          boardView:(BoardView *)bView;
- (void)moveToSquare:(Square)newSquare;

@end
