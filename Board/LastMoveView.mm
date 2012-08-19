#import "LastMoveView.h"
#import "Board.h"

@implementation LastMoveView

- (id)initWithFrame:(CGRect)frame fromSquare:(Square)fromSquare toSquare:(Square)toSquare {
    if (self = [super initWithFrame:frame]) {
        square1 = fromSquare;
        square2 = toSquare;
        squareSize = frame.size.width / 8;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [self drawSquare: square1];
    [self drawSquare: square2]  ;
}

- (void)drawSquare:(Square) square {
    [[Board highlightColor] set];
    int f = int(square_file(square));
    int r = 7 - int(square_rank(square));
    CGRect frame = CGRectMake(f * squareSize, r * squareSize, squareSize, squareSize);
    UIRectFrame(frame);
    UIRectFrame(CGRectInset(frame, 1.0f, 1.0f));
    UIRectFrame(CGRectInset(frame, 2.0f, 2.0f));
    UIRectFrame(CGRectInset(frame, 3.0f, 3.0f));
}

@end


