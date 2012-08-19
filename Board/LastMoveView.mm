#import "LastMoveView.h"
#import "Board.h"

using namespace Chess;

@implementation LastMoveView

- (id)initWithFrame:(CGRect)frame fromSquare:(Square)fromSquare toSquare:(Square)toSquare {
    self = [super initWithFrame:frame];
    if (!self) return self;
    
    move = make_move(fromSquare, toSquare);
    squareSize = frame.size.width / 8;
    
    return self;
}

- (void)drawRect:(CGRect)rect {
    [self drawSquare: move_from(move)];
    [self drawSquare: move_to(move)];
}

- (void)drawSquare:(Square)square {
    int file = int(square_file(square));
    int rank = 7 - int(square_rank(square));
    CGRect frame = CGRectMake(file * squareSize, rank * squareSize, squareSize, squareSize);
    [[Board highlightColor] set];
    for (int i = 0; i < 4; ++i) {
        UIRectFrame(CGRectInset(frame, i, i));
    }
}

@end


