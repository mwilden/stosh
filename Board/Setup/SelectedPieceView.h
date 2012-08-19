#include "piece.h"

using namespace Chess;

@interface SelectionRectangle : UIView {
   float sqSize;
}
- (void)moveToPoint:(CGPoint)point;
@end


@interface SelectedPieceView : UIView {
   Piece selectedPiece;
   SelectionRectangle *selRect;
   float sqSize;
}

@property (nonatomic, readonly) Piece selectedPiece;

@end
