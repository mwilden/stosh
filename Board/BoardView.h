#import <UIKit/UIKit.h>

#include "../Chess/square.h"

using namespace Chess;

@class GameController;
@class HighlightedSquaresView;
@class LastMoveView;
@class SelectedSquareView;

@interface BoardView : UIView {
   UIColor *darkSquareColor, *lightSquareColor;
   UIImage *darkSquareImage, *lightSquareImage;
   GameController *gameController;
   HighlightedSquaresView *highlightedSquaresView;
   Square highlightedSquares[32];
   SelectedSquareView *selectedSquareView;
   Square fromSquare, selectedSquare;
   LastMoveView *lastMoveView;
   float sqSize;
}

@property (nonatomic, assign) GameController *gameController;
@property (nonatomic, readonly) Square fromSquare;
@property (nonatomic, readonly) float sqSize;

- (Square)squareAtPoint:(CGPoint)point;
- (CGPoint)originOfSquare:(Square)sq;
- (CGRect)rectForSquare:(Square)sq;
- (void)selectionMovedToPoint:(CGPoint)sq;
- (void)showLastMoveWithFrom:(Square)s1 to:(Square)s2;
- (void)hideLastMove;
- (void)pieceTouchedAtSquare:(Square)s;

@end
