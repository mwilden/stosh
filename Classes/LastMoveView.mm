#import "LastMoveView.h"
#import "Options.h"

@implementation LastMoveView


- (id)initWithFrame:(CGRect)frame fromSq:(Square)fSq toSq:(Square)tSq {
   if (self = [super initWithFrame:frame]) {
      square1 = fSq;
      square2 = tSq;
      sqSize = frame.size.width / 8;
   }
   return self;
}


- (void)drawRect:(CGRect)rect {
   int f, r;

   [[[Options sharedOptions] highlightColor] set];
   CGRect frame;

   f = int(square_file(square1));
   r = 7 - int(square_rank(square1));
   frame = CGRectMake(f*sqSize, r*sqSize, sqSize, sqSize);
   UIRectFrame(frame);
   UIRectFrame(CGRectInset(frame, 1.0f, 1.0f));
   UIRectFrame(CGRectInset(frame, 2.0f, 2.0f));
   UIRectFrame(CGRectInset(frame, 3.0f, 3.0f));
   f = int(square_file(square2));
   r = 7 - int(square_rank(square2));
   frame = CGRectMake(f*sqSize, r*sqSize, sqSize, sqSize);
   UIRectFrame(frame);
   UIRectFrame(CGRectInset(frame, 1.0f, 1.0f));
   UIRectFrame(CGRectInset(frame, 2.0f, 2.0f));
   UIRectFrame(CGRectInset(frame, 3.0f, 3.0f));
}


- (void)dealloc {
   [super dealloc];
}


@end
