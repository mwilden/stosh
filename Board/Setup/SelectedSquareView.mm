#import "SelectedSquareView.h"

@implementation SelectedSquareView

- (id)initWithFrame:(CGRect)frame {
   if (self = [super initWithFrame:frame]) {
      hidden = YES;
      size = frame.size.width;
   }
   return self;
}


- (void)drawRect:(CGRect)rect {
   if (!hidden) {
      [[UIColor blackColor] set];
      UIRectFrame(CGRectMake(1.0f, 1.0f, size-1, size-1));
      UIRectFrame(CGRectMake(2.0f, 2.0f, size-3, size-3));
      UIRectFrame(CGRectMake(3.0f, 3.0f, size-5, size-5));
      UIRectFrame(CGRectMake(4.0f, 4.0f, size-7, size-7));
   }
}


- (void)hide {
   hidden = YES;
   [self setNeedsDisplay];
   [super setNeedsDisplay];
}


- (void)moveToPoint:(CGPoint)point {
   CGRect r = [self frame];
   r.origin = point;
   hidden = NO;
   [self setFrame: r];
   [self setNeedsDisplay];
}


- (void)dealloc {
   [super dealloc];
}


@end
