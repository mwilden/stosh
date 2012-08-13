#import "ChessMove.h"

@implementation ChessMove

@synthesize move, undoInfo;

- (id)initWithMove:(Move)m undoInfo:(UndoInfo)ui {
   if (self = [super init]) {
      move = m;
      undoInfo = ui;
   }
   return self;
}

@end
