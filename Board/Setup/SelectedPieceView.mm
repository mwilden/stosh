#import "Board.h"
#import "SelectedPieceView.h"

@implementation SelectionRectangle : UIView {
}

- (id)initWithFrame:(CGRect)frame {
   if (self = [super initWithFrame: frame]) {
      sqSize = frame.size.width / 8;
   }
   return self;
}

- (void)drawRect:(CGRect)rect {
   [[Board highlightColor] set];
   UIRectFrame(CGRectMake(0.0f, 0.0f, 40.0f, 40.0f));
   UIRectFrame(CGRectMake(1.0f, 1.0f, 38.0f, 38.0f));
   /*
     UIRectFrame(CGRectMake(0.0f, 0.0f, sqSize, sqSize));
     UIRectFrame(CGRectMake(1.0f, 1.0f, sqSize-2.0, sqSize-2.0));
   */
}


- (void)moveToPoint:(CGPoint)point {
   CGRect r = [self frame];

   CGContextRef context = UIGraphicsGetCurrentContext();
   [UIView beginAnimations: nil context: context];
   [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
   [UIView setAnimationDuration: 0.2];
   r.origin = point;
   [self setFrame: r];
   [self setNeedsDisplay];
   [UIView commitAnimations];
}

@end


@implementation SelectedPieceView

@synthesize selectedPiece;

- (id)initWithFrame:(CGRect)frame {
   if (self = [super initWithFrame: frame]) {
      //sqSize = frame.size.width / 8;
      sqSize = 40.0f;

      UIImage *pieceImages[16];

      static NSString *pieceImageNames[16] = {
         nil, @"WPawn", @"WKnight", @"WBishop", @"WRook",
         @"WQueen", @"WKing", nil, nil, @"BPawn", @"BKnight",
         @"BBishop", @"BRook", @"BQueen", @"BKing", nil
      };
      NSString *pieceSet = @"USCF";
      for (Piece p = WP; p <= BK; p++) {
         if (piece_is_ok(p))
            pieceImages[p] =
               [[UIImage imageNamed: [NSString stringWithFormat: @"%@%@.tiff",
                                               pieceSet,
                                               pieceImageNames[p]]]
                  retain];
         else
            pieceImages[p] = nil;
      }
      UIImageView *iv;
      for (int i = 0; i < 6; i++)
         for (int j = 0; j < 2; j++) {
            CGRect r = CGRectMake(i*sqSize, j*sqSize, sqSize, sqSize);
            iv = [[UIImageView alloc] initWithFrame: r];
            [iv setImage: pieceImages[(i+1) + (1-j)*8]];
            [self addSubview: iv];
            [iv release];
         }
      for (Piece p = WP; p <= BK; p++)
         [pieceImages[p] release];
      selRect = [[SelectionRectangle alloc]
                  initWithFrame: CGRectMake(0.0f, sqSize, sqSize, sqSize)];
      [selRect setOpaque: NO];
      [self addSubview: selRect];

      selectedPiece = WP;


   }
   return self;
}

- (void)drawRect:(CGRect)rect {
    int i, j;
    UIColor *darkSquareColor = [Board darkSquareColor];
    UIColor *lightSquareColor = [Board lightSquareColor];
    for (i = 0; i < 6; i++)
        for (j = 0; j < 2; j++) {
            [(((i + j) & 1)? lightSquareColor : darkSquareColor) set];
            UIRectFill(CGRectMake(i*sqSize, j*sqSize, sqSize, sqSize));
        }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
   CGPoint pt = [[touches anyObject] locationInView: self];
   int row = (int)(pt.y / sqSize);
   int column = (int)(pt.x / sqSize);
   [selRect moveToPoint: CGPointMake(column*sqSize, row*sqSize)];
   selectedPiece = piece_of_color_and_type(Color(1-row), PieceType(1+column));
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
   CGPoint pt = [[touches anyObject] locationInView: self];
   int row = (int)(pt.y / sqSize);
   int column = (int)(pt.x / sqSize);
   [selRect moveToPoint: CGPointMake(column*sqSize, row*sqSize)];
   selectedPiece = piece_of_color_and_type(Color(1-row), PieceType(1+column));
}


- (void)dealloc {
   [super dealloc];
}


@end
