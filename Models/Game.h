@class GameController;
@class ChessMove;

#import "position.h"

using namespace Chess;

@interface Game : NSObject {
   GameController *gameController;
   NSString *startFEN;
   Position *startPosition;
   Position *currentPosition;
   NSMutableArray *moves;
   int currentMoveIndex;

   NSString *event;
   NSString *site;
   NSString *date;
   NSString *round;
   NSString *whitePlayer;
   NSString *blackPlayer;
   NSString *result;
}

@property (nonatomic, retain) NSString *event;
@property (nonatomic, retain) NSString *site;
@property (nonatomic, retain) NSString *date;
@property (nonatomic, retain) NSString *round;
@property (nonatomic, retain) NSString *whitePlayer;
@property (nonatomic, retain) NSString *blackPlayer;
@property (nonatomic, retain) NSString *result;
@property (nonatomic, readonly) int currentMoveIndex;

- (id)initWithGameController:(GameController *)gc FEN:(NSString *)fen;
- (id)initWithGameController:(GameController *)gc PGNString:(NSString *)string;
- (id)initWithGameController:(GameController *)gc;
- (Color)sideToMove;
- (Piece)pieceOn:(Square)sq;
- (BOOL)pieceCanMoveFrom:(Square)sq;
- (int)pieceCanMoveFrom:(Square)fSq to:(Square)tSq;
- (int)generateLegalMoves:(Move *)mlist;
- (int)movesFrom:(Square)sq saveInArray:(Move *)mlist;
- (int)destinationSquaresFrom:(Square)sq saveInArray:(Square *)sqs;
- (void)doMove:(Move)m;
- (Move)doMoveFrom:(Square)fSq to:(Square)tSq promotion:(PieceType)prom;
- (void)doMoveFrom:(Square)fSq to:(Square)tSq;
- (BOOL)atBeginning;
- (BOOL)atEnd;
- (void)takeBack;
- (void)stepForward;
- (void)toBeginning;
- (void)toEnd;
- (ChessMove *)previousMove;
- (ChessMove *)nextMove;
- (NSString *)moveListString;
- (NSString *)partialMoveListString;
- (NSString *)pgnString;
- (NSString *)uciGameString;
- (Move)moveFromString:(NSString *)string;
- (BOOL)positionIsMate;
- (BOOL)positionIsDraw;
- (NSString *)drawReason;
- (BOOL)positionIsTerminal;
- (BOOL)positionAfterMoveIsTerminal:(Move)m;
- (void)addComment: (NSString *)comment;
- (Move)currentMove;
- (NSString *)currentFEN;

@end
