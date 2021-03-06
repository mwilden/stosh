#import "GameController.h"
#import "PieceImageView.h"
#import "BoardView.h"

@implementation PieceImageView

@synthesize location, square;

- (id)initWithFrame:(CGRect)frame
     gameController:(GameController *)controller
          boardView:(BoardView *)bView {
   if (self = [super initWithFrame: frame]) {
      squareSize = [bView squareSize];
      square = make_square(File(frame.origin.x / squareSize),
                           Rank((7*squareSize - frame.origin.y) / squareSize));
      location = frame.origin;
      gameController = controller;
      boardView = bView;
      isBeingDragged = NO;
      wasDraggedAwayFromSquare = NO;
   }
   return self;
}


- (void)moveAnimationFinished2:(NSString *)animationID
                      finished:(BOOL)finished
                       context:(void *)context {
   [gameController piecesSetUserInteractionEnabled: YES];
}


- (void)moveAnimationFinished:(NSString *)animationID
                     finished:(BOOL)finished
                      context:(void *)context {
   CGRect rect = CGRectMake(0.0f, 0.0f, squareSize, squareSize);
   CGPoint endPt = CGPointMake(int(square_file(square)) * squareSize,
                               (7-int(square_rank(square))) * squareSize);

   [UIView beginAnimations: nil context: context];
   [UIView setAnimationDelegate: self];
   [UIView setAnimationDidStopSelector:
              @selector(moveAnimationFinished2:finished:context:)];
   [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
   [UIView setAnimationDuration: 0.08];
   rect.origin = endPt;
   [self setFrame: rect];
   [UIView commitAnimations];
}


- (void)fastMoveAnimationFinished:(NSString *)animationID
                         finished:(BOOL)finished
                          context:(void *)context {
   CGRect rect = CGRectMake(0.0f, 0.0f, squareSize, squareSize);
   CGPoint endPt = CGPointMake(int(square_file(square)) * squareSize,
                               (7-int(square_rank(square))) * squareSize);

   [UIView beginAnimations: nil context: context];
   [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
   [UIView setAnimationDuration: 0.04];
   rect.origin = endPt;
   [self setFrame: rect];
   [UIView commitAnimations];
}


/// Move the piece to a new square. If the code looks a little messy, it is
/// because of the fancy animation.

- (void)moveToSquare:(Square)newSquare {
   assert(square_is_ok(newSquare));

   // Make sure the user doesn't try to move a piece during the animation,
   // because this may crash the program:
   [gameController piecesSetUserInteractionEnabled: NO];
   square = newSquare;

   CGPoint startPt = [self frame].origin;
   CGPoint endPt = CGPointMake(int(square_file(square)) * squareSize,
                               (7-int(square_rank(square))) * squareSize);
   CGPoint pt = CGPointMake(endPt.x + (endPt.x - startPt.x) * 0.15f,
                            endPt.y + (endPt.y - startPt.y) * 0.15f);
   CGRect rect = CGRectMake(0.0f, 0.0f, squareSize, squareSize);
   CGContextRef context = UIGraphicsGetCurrentContext();

   [[self superview] bringSubviewToFront: self];
   [UIView beginAnimations: nil context: context];
   [UIView setAnimationDelegate: self];
   [UIView setAnimationDidStopSelector:
              @selector(moveAnimationFinished:finished:context:)];
   [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
   [UIView setAnimationDuration: 0.20];
   rect.origin = pt;
   [self setFrame: rect];
   [UIView commitAnimations];
}


/// Handle a touchesBegan event: If the piece has any legal moves, allow the
/// user to drag the view around. This method only records the view's original
/// location; the actual dragging is handled by the touchesMoved:withEvent:
/// method.

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
   Square sqs[32];

   if ([boardView fromSquare] != SQ_NONE)
      [boardView touchesBegan: touches withEvent: event];
   else {
      [boardView hideLastMove];
      if ([gameController destinationSquaresFrom: square saveInArray: sqs]) {
         // Messaging the board view directly from here is perhaps not entirely
         // kosher.  Perhaps we should communicate with the board view using
         // the game controller?
         CGPoint pt = [[touches anyObject] locationInView: self];
         oldFrame = [self frame];
         location = pt;
         [[self superview] bringSubviewToFront: self];
         isBeingDragged = YES;
         wasDraggedAwayFromSquare = NO;
      }
   }
}


/// Handle touchesMoved event: If the pieces has any legal moves, allow the
/// user to drag the view around.

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
   if (isBeingDragged) {
      id obj = [touches anyObject];
      CGPoint pt = [obj locationInView: self];
      CGPoint boardPt = [obj locationInView: boardView];
      CGRect frame = [self frame];

      frame.origin.x += pt.x - location.x;
      frame.origin.y += pt.y - location.y;
      [self setFrame: frame];

      if (!wasDraggedAwayFromSquare &&
          [boardView squareAtPoint: boardPt] != square) {
         wasDraggedAwayFromSquare = YES;
      }
   }
}


/// Handle touchesEnded event. If the piece was released at a legal destination
/// square, make the move. If not, move the piece view back to its source
/// square. The code is a little messy, because we use a fancy animation.

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
   if (isBeingDragged) {
      isBeingDragged = NO;
      CGPoint releasePoint = [[touches anyObject]
                                locationInView: [self superview]];
      Square releasedSquare = [boardView squareAtPoint: releasePoint];

      if ([gameController pieceCanMoveFrom: square to: releasedSquare]) {
         // Make the piece slide smoothly to the center of the square:

         CGPoint endPt =
            CGPointMake(int(square_file(releasedSquare)) * squareSize,
                        (7-int(square_rank(releasedSquare))) * squareSize);
         CGRect rect = CGRectMake(0.0f, 0.0f, squareSize, squareSize);
         CGContextRef context = UIGraphicsGetCurrentContext();
         [UIView beginAnimations: nil context: context];
         [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
         [UIView setAnimationDuration: 0.10];
         rect.origin = endPt;
         [self setFrame: rect];
         [UIView commitAnimations];

         // Update the game
         [gameController doMoveFrom: square
                                 to: releasedSquare
                          promotion: NO_PIECE_TYPE];
         if (![gameController moveIsPending]) { // HACK to handle promotions
            square = releasedSquare;
         }
      }
      else {
         // Not a legal destination square, let the piece slide back to its old
         // square.
         CGPoint oldOrigin = [self frame].origin;
         CGPoint newOrigin = oldFrame.origin;
         CGPoint pt = CGPointMake(newOrigin.x + (newOrigin.x-oldOrigin.x)*0.15f,
                                  newOrigin.y + (newOrigin.y-oldOrigin.y)*0.15f);
         CGRect rect = oldFrame;
         CGContextRef context = UIGraphicsGetCurrentContext();
         rect.origin = pt;
         [UIView beginAnimations: nil context: context];
         [UIView setAnimationDelegate: self];
         [UIView setAnimationDidStopSelector:
                    @selector(moveAnimationFinished:finished:context:)];
         [UIView setAnimationDuration: 0.20];
         [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
         [self setFrame: rect];
         [UIView commitAnimations];

         // If the piece was never dragged away from it's source square, tell
         // the board view that it was touched, to make the "two-tap" move entry
         // method work.
         if (!wasDraggedAwayFromSquare) {
            [boardView pieceTouchedAtSquare: square];
            return;
         }
      }
   }
   wasDraggedAwayFromSquare = NO;
}

@end
