#import "GameController.h"
#import "MoveListView.h"


@implementation MoveListView

@synthesize gameController;

- (id)initWithFrame:(CGRect)frame {
   if (self = [super initWithFrame: frame]) {
      [self setScrollEnabled: NO];
   }
   return self;
}


- (void)drawRect:(CGRect)rect {
   // Drawing code
}


/// Touch gestures in the move list view: Swiping the finger to the left or
/// right is used to take back or replay moves.

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
   touchStartPoint = [[touches anyObject] locationInView: self];
   horizontalSwipe = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
   if (horizontalSwipe) {
      CGPoint pt = [[touches anyObject] locationInView: self];
      if (abs(pt.x - touchStartPoint.x) < 12.0
          && abs(pt.y - touchStartPoint.y) > 10.0f) {
         NSLog(@"no longer horizontal swipe");
         horizontalSwipe = NO;
      }
   }
   else
      // Hand over the touch event to superclass, to support scrolling.
      [super touchesMoved: touches withEvent: event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
   NSLog(@"touches ended");
   if (horizontalSwipe) {
      CGPoint pt = [[touches anyObject] locationInView: self];
      if (pt.x - touchStartPoint.x > 12.0f)
         [gameController replayMove];
      else if (pt.x - touchStartPoint.x < -12.0)
         [gameController takeBackMove];
   }
}


/// Override UITextView's setText: method by converting hyphens to non-breaking
/// hyphens, to prevent notation of castling moves to be split between two
/// lines.

- (void)setText:(NSString *)string {
   unichar c = 0x2011;
   NSString *s = [NSString stringWithCharacters: &c length: 1];

   string = [string stringByReplacingOccurrencesOfString: @"-"
                                              withString: s];

   [super setText: string];
}


@end
