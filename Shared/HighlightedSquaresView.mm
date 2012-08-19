#import "HighlightedSquaresView.h"

@implementation HighlightedSquaresView

@dynamic selectedSquare;

- (id)initWithFrame:(CGRect)frame squares:(Square *)sqs {
   if (self = [super initWithFrame: frame]) {
      int i;
      for (i = 0; sqs[i] != SQ_NONE; i++)
         squares[i] = sqs[i];
      squares[i] = SQ_NONE;
      selectedSquare = SQ_NONE;
      squareSize = frame.size.width / 8;
   }
   return self;
}


/// drawRect: simply draws little ellipses in the center of each square.
/// Perhaps we should switch to something prettier later.

- (void)drawRect:(CGRect)rect {
}


- (Square)selectedSquare {
   return selectedSquare;
}


- (void)setSelectedSquare:(Square)s {
   selectedSquare = s;
   [self setNeedsDisplay];
}


- (void)dealloc {
   [super dealloc];
}


@end
