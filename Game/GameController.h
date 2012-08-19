@class BoardView;
@class Game;
@class LastMoveView;
@class MoveListView;
@class PieceImageView;

#include "position.h"

using namespace Chess;

@interface GameController : NSObject <UIActionSheetDelegate> {
   BoardView *boardView;
   MoveListView *moveListView;
   Game *game;
   NSMutableArray *pieceViews;
   UIImage *pieceImages[16];
   Square pendingFrom, pendingTo; // HACK for handling promotions.
   BOOL rotated;
   NSTimer *timer;
   LastMoveView *lastMoveView;
}

@property (nonatomic, readonly) Game *game;
@property (nonatomic, readonly) BOOL rotated;

- (id)initWithBoardView:(BoardView *)bv
           moveListView:(MoveListView *)mlv;
- (void)startNewGame;
- (void)updateMoveList;
- (BOOL)moveIsPending;
- (Piece)pieceOn:(Square)sq;
- (BOOL)pieceCanMoveFrom:(Square)sq;
- (int)pieceCanMoveFrom:(Square)fSq to:(Square)tSq;
- (int)destinationSquaresFrom:(Square)sq saveInArray:(Square *)sqs;
- (void)doMoveFrom:(Square)fSq to:(Square)tSq promotion:(PieceType)prom;
- (void)animateMoveFrom:(Square)fSq to:(Square)tSq;
- (void)removePieceOn:(Square)sq;
- (void)putPiece:(Piece)p on:(Square)sq;
- (void)animateMove:(Move)m;
- (void)takeBackMove;
- (void)replayMove;
- (void)takeBackAllMoves;
- (void)replayAllMoves;
- (void)showPieces;
- (PieceImageView *)pieceImageViewForSquare:(Square)sq;
- (void)rotateBoard;
- (void)rotateBoard:(BOOL)rotate;
- (void)gameEndTest;
- (void)loadPieceImages;
- (void)gameFromPGNString:(NSString *)pgnString;
- (void)gameFromFEN:(NSString *)fen;
- (void)piecesSetUserInteractionEnabled:(BOOL)enable;
- (void)redrawPieces;

@end
