#include "piece.h"

using namespace Chess;

@interface SelectionRectangle : UIView {
   float squareSize;
}
- (void)moveToPoint:(CGPoint)point;
@end


@interface SelectedPieceView : UIView {
   Piece selectedPiece;
   SelectionRectangle *selRect;
   float squareSize;
}

@property (nonatomic, readonly) Piece selectedPiece;

@end
