#include "square.h"

using namespace Chess;

@interface HighlightedSquaresView : UIView {
   Square squares[32];
   Square selectedSquare;
   float sqSize;
}

@property (nonatomic, assign) Square selectedSquare;

- (id)initWithFrame:(CGRect)frame squares:(Square *)sqs;

@end
