#include "square.h"

using namespace Chess;

@class GameController;
@class HighlightedSquaresView;
@class LastMoveView;
@class SelectedSquareView;

@interface BoardView : UIView {
   GameController *gameController;
   HighlightedSquaresView *highlightedSquaresView;
   Square highlightedSquares[32];
   SelectedSquareView *selectedSquareView;
   Square fromSquare, selectedSquare;
   LastMoveView *lastMoveView;
   float squareSize;
}

@property (nonatomic, assign) GameController *gameController;
@property (nonatomic, readonly) Square fromSquare;
@property (nonatomic, readonly) float squareSize;

- (Square)squareAtPoint:(CGPoint)point;
- (CGPoint)originOfSquare:(Square)sq;
- (CGRect)rectForSquare:(Square)sq;
- (void)selectionMovedToPoint:(CGPoint)sq;
- (void)showLastMoveWithFrom:(Square)s1 to:(Square)s2;
- (void)hideLastMove;
- (void)pieceTouchedAtSquare:(Square)s;

@end
