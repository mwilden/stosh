#import "Game.h"
#import "GameController.h"
#import "GameParser.h"
#import "PGN.h"
#import "ChessMove.h"

#include "san.h"

@implementation Game

@synthesize event, site, date, round, whitePlayer, blackPlayer, result, currentMoveIndex;


/// initWithGameController:FEN: initializes a game from a FEN representing the
/// initial position of the game.

- (id)initWithGameController:(GameController *)gc FEN:(NSString *)fen {
   if (self = [super init]) {
      gameController = gc;
      startFEN = [fen retain];
      currentPosition = new Position;
      startPosition = new Position;
      startPosition->from_fen([fen UTF8String]);
      currentPosition->copy(*startPosition);

      moves = [[NSMutableArray alloc] init];
      currentMoveIndex = 0;

      whitePlayer = @"White";
      blackPlayer = @"Black";
      event = [[NSString alloc] initWithString: @"?"];
      site = [[NSString alloc] initWithString: @"?"];

      // TODO: Correct date format.
      NSDate *today = [[NSDate alloc] init];
      NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
      [dateFormatter setDateStyle: NSDateFormatterMediumStyle];
      date = [[dateFormatter stringFromDate: today] retain];
      [today release];
      [dateFormatter release];

      round = [[NSString alloc] initWithString: @"?"];
      result = [[NSString alloc] initWithString: @"*"];
   }
   return self;
}


- (id)initWithGameController:(GameController *)gc PGNString:(NSString *)string {
   self = [self initWithGameController: gc];

   GameParser *gp = [[GameParser alloc] initWithString: string];
   PGNToken token[1];
   char name[PGN_STRING_SIZE], value[PGN_STRING_SIZE];

   // Scan for PGN headers first:
   while (YES) {
      [gp getNextToken: token];
      if (token->type != '[') break;
      [gp getNextToken: token];

      if (token->type != TOKEN_SYMBOL)
         [[NSException exceptionWithName: @"PGNHeaderException"
                                  reason: @"Invalid PGN header"
                                userInfo: nil]
            raise];

      strcpy(name, token->string);
      [gp getNextToken: token];

      if (token->type != TOKEN_STRING)
         [[NSException exceptionWithName: @"PGNHeaderException"
                                  reason: @"Invalid PGN header"
                                userInfo: nil]
            raise];

      strcpy(value, token->string);
      [gp getNextToken: token];

      if (token->type != ']')
         [[NSException exceptionWithName: @"PGNHeaderException"
                                  reason: @"Invalid PGN header"
                                userInfo: nil]
            raise];

      // OK, now we have a PGN tag consisting of a (name, value) pair.  Is
      // it one of the tags we care about?
      if (NO) {
      } else if (strcmp(name, "White") == 0) {
         [self setWhitePlayer: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Black") == 0) {
         [self setBlackPlayer: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Event") == 0) {
         [self setEvent: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Site") == 0) {
         [self setSite: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Round") == 0) {
         [self setRound: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Date") == 0) {
         [self setDate: [NSString stringWithUTF8String: value]];
      } else if (strcmp(name, "Result") == 0) {
         [self setResult: [NSString stringWithUTF8String: value]];
      } else if (strncmp(name, "FEN", 3) == 0) {
         [startFEN release];
         startFEN = [[NSString stringWithUTF8String: value] retain];
         startPosition->from_fen([startFEN UTF8String]);
         currentPosition->copy(*startPosition);
      }
   }

   int depth = 0;
   do {
      if (NO) {
      } else if (token->type == '{') {
         [self addComment: [gp readComment]];
      } else if (token->type == '(') {
         // Beginning of a RAV.
         depth++;
      } else if (token->type == ')') {
         // End of a RAV.
         depth--;
      } else if (token->type == TOKEN_NAG) {
         // [self addNAG: atoi(token->string)];
      } else if (depth == 0 && token->type == TOKEN_SYMBOL) {
         // This should be a move. Try to parse it:
         Move m = move_from_san(*currentPosition, token->string);
         if (m != MOVE_NONE) {
            UndoInfo u;
            currentPosition->do_move(m, u);
            ChessMove *cm = [[ChessMove alloc] initWithMove: m undoInfo: u];
            [moves addObject: cm];
            [cm release];
            currentMoveIndex++;
         }
         else {
            NSLog(@"illegal move: %s", token->string);
            [[NSException exceptionWithName: @"PGNException"
                                     reason: @"Illegal move"
                                   userInfo: nil] raise];
         }
      }
      else if (token->type == TOKEN_RESULT || token->type == TOKEN_EOF) {
         // Finished
         break;
      }
   } while ([gp getNextToken: token]);

   [gp release];

   return self;
}


/// init initializes a game to the standard starting position.

- (id)initWithGameController: (GameController *)gc {
   return [self initWithGameController: gc
                                   FEN: @"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"];
}


/// The side to move in the current game position.

- (Color)sideToMove {
   return currentPosition->side_to_move();
}


/// pieceOn: returns the piece on a given square in the current game position.

- (Piece)pieceOn:(Square)sq {
   assert(square_is_ok(sq));
   return currentPosition->piece_on(sq);
}


/// pieceCanMoveFrom: takes a square as input, and returns YES or NO depending
/// on whether the piece on that square in the current position has any legal
/// moves.

- (BOOL)pieceCanMoveFrom:(Square)sq {
   Move mlist[32];

   assert(square_is_ok(sq));
   return currentPosition->moves_from(sq, mlist) > 0;
}


/// destinationSquaresFrom:saveInArray takes a square and a C array of squares
/// as input, finds all squares the piece on the given square can move to,
/// and stores these possible destination squares in the array. This is used
/// in the GUI in order to highlight the squares a piece can move to.

- (int)movesFrom:(Square)sq saveInArray:(Move *)mlist {
   assert(square_is_ok(sq));
   assert(mlist != NULL);

   return currentPosition->moves_from(sq, mlist);
}

- (int)destinationSquaresFrom:(Square)sq saveInArray:(Square *)sqs {
   Move mlist[32];
   int i, j, n;

   assert(square_is_ok(sq));
   assert(sqs != NULL);

   n = currentPosition->moves_from(sq, mlist);
   for (i = 0, j = 0; i < n; i++)
      // Only include non-promotions and queen promotions, in order to avoid
      // having the same destination squares multiple times in the array.
      if (!move_promotion(mlist[i]) || move_promotion(mlist[i]) == QUEEN)
         sqs[j++] = move_to(mlist[i]);
   sqs[j] = SQ_NONE;
   return j;
}


/// pieceCanMoveFrom:to: takes a source square and a destination square as
/// input, and returns the number of legal moves between the two squares in
/// the current game position. The number of legal moves is usually 0 or 1,
/// but can be more for positions with pawn promotions.

- (int)pieceCanMoveFrom:(Square)fSq to:(Square)tSq {
   Move mlist[32];
   int i, n, count;

   assert(square_is_ok(fSq));
   assert(square_is_ok(tSq));
   n = currentPosition->moves_from(fSq, mlist);
   for (i = 0, count = 0; i < n; i++)
      if (move_to(mlist[i]) == tSq)
         count++;
   return count;
}


/// generateLegalMoves: Generate all legal moves from the current position
/// and saves them in an array. It returns the number of legal moves.

- (int)generateLegalMoves:(Move *)mlist {
   assert(mlist != NULL);
   return currentPosition->all_legal_moves(mlist);
}


/// doMove: takes a move as input, executes the move, and updates the current
/// position and move list.  The move is assumed to be legal.

- (void)doMove:(Move)m {
   UndoInfo u;
   currentPosition->do_move(m, u);
   ChessMove *cm = [[ChessMove alloc] initWithMove: m undoInfo: u];
   if (![self atEnd]) {
      // We are not at the end of the game. We don't want to mess with
      // multiple variations in the game on the iPhone, so we just remove
      // all moves at the end of the move list.
      [moves removeObjectsInRange:
                NSMakeRange(currentMoveIndex, [moves count] - currentMoveIndex)];
   }
   [moves addObject: cm];
   [cm release];
   currentMoveIndex++;

   assert([self atEnd]);
}

/// doMoveFrom:to:promotion: takes a source square, a destination square and
/// a piece type representing a promotion as input, finds the matching legal
/// move, and updates the current position and the move list. It is assumed
/// that a single legal move matches the input parameters.

- (Move)doMoveFrom:(Square)fSq to:(Square)tSq promotion:(PieceType)prom {
   assert(square_is_ok(fSq));
   assert(square_is_ok(tSq));
   assert(prom == NO_PIECE_TYPE || (prom >= KNIGHT && prom <= QUEEN));

   // Find the matching move
   Move mlist[32], move;
   int n, i, matches;
   n = currentPosition->moves_from(fSq, mlist);
   for (i = 0, matches = 0; i < n; i++)
      if (move_to(mlist[i]) == tSq && move_promotion(mlist[i]) == prom) {
         move = mlist[i];
         matches++;
      }
   assert(matches == 1);

   // Update position
   UndoInfo u;
   currentPosition->do_move(move, u);

   // Update move list
   ChessMove *cm = [[ChessMove alloc] initWithMove: move undoInfo: u];
   if (![self atEnd]) {
      // We are not at the end of the game. We don't want to mess with
      // multiple variations in the game on the iPhone, so we just remove
      // all moves at the end of the move list.
      [moves removeObjectsInRange:
                NSMakeRange(currentMoveIndex, [moves count] - currentMoveIndex)];
   }
   [moves addObject: cm];
   [cm release];
   currentMoveIndex++;

   assert([self atEnd]);

   return move;
}


/// doMoveFrom:to takes a source square and a destination square as input,
/// finds the matching legal move, and updates the current position and the
/// move list. It is assumed that a single legal move matches the input
/// parameters.

- (void)doMoveFrom:(Square)fSq to:(Square)tSq {
   [self doMoveFrom: fSq to: tSq promotion: NO_PIECE_TYPE];
}


/// atBeginning tests whether we are at the beginning of the game.

- (BOOL)atBeginning {
   return currentMoveIndex == 0;
}


/// atEnd tests whether we are at the end of the game.

- (BOOL)atEnd {
   return currentMoveIndex == [moves count];
}


/// takeBack takes back one move from the current position, without deleting
/// the move from the move list. If we are already at the beginning of the
/// game, nothing happens.

- (void)takeBack {
   if (![self atBeginning]) {
      currentMoveIndex--;
      ChessMove *cm = [moves objectAtIndex: currentMoveIndex];
      Move m = [cm move];
      UndoInfo u = [cm undoInfo];
      currentPosition->undo_move(m, u);
   }
}


/// stepForward steps forward one move in the move list. If we are alread at
/// the end of the move list, nothing happens.

- (void)stepForward {
   if (![self atEnd]) {
      ChessMove *cm = [moves objectAtIndex: currentMoveIndex];
      Move m = [cm move];
      UndoInfo u = [cm undoInfo];
      currentPosition->do_move(m, u);
      currentMoveIndex++;
   }
}


- (void)toBeginning {
   while (![self atBeginning])
      [self takeBack];
}


- (void)toEnd {
   while (![self atEnd])
      [self stepForward];
}


/// previousMove returns the move made to reach the current position, or nil
/// if we are at the beginning of the game.

- (ChessMove *)previousMove {
   return [self atBeginning]?
      nil :
      [moves objectAtIndex: currentMoveIndex - 1];
}


/// nextMove returns the next move played in the game from the current
/// position, or nil if we are at the end of the game.

- (ChessMove *)nextMove {
   return [self atEnd]?
      nil :
      [moves objectAtIndex: currentMoveIndex];
}


/// moveListString returns an NSString representing the entire game in short
/// algebraic notation.

- (NSString *)moveListString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves)
      line[i++] = [move move];
   line[i] = MOVE_NONE;
   return [NSString stringWithUTF8String:
                       line_to_san(*startPosition, line, 0, false, 1).c_str()];
}


/// partialMoveListString returns an NSString representing the game up to the
/// current move in short algebraic notation.

- (NSString *)partialMoveListString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves) {
      line[i++] = [move move];
      if (i >= currentMoveIndex) break;
   }
   line[i] = MOVE_NONE;
   return [NSString stringWithUTF8String:
                       line_to_san(*startPosition, line, 0, false, 1).c_str()];
}


static NSString* breakLinesInString(NSString *string) {
   NSScanner *scanner = [[NSScanner alloc] initWithString: string];
   NSCharacterSet *charSet =
      [[NSCharacterSet whitespaceCharacterSet] invertedSet];
   NSString *str;
   NSMutableString *mstr;
   NSMutableArray *array = [[NSMutableArray alloc] init];
   int i, j;

   // Split 'string' into white-space separated tokens, and store them into
   // 'array':
   while (![scanner isAtEnd]) {
      [scanner scanCharactersFromSet: charSet intoString: &str];
      [array addObject: str];
   }
   [scanner release];

   // Build new string:
   mstr = [NSMutableString stringWithString: @""];
   j = 0;
   for (i = 0; i < [array count]; i++) {
      int length = [[array objectAtIndex: i] length];
      if (j + length + 1 < 80) {
         if (i > 0) { // HACK
            [mstr appendString: @" "];
            j += length + 1;
         }
         else j += length;
      }
      else {
         [mstr appendString: @"\n"];
         j = length;
      }
      [mstr appendString: [array objectAtIndex: i]];
   }
   [array release];
   return [NSString stringWithString: mstr];
}

/// pgnMoveListString returns an NSString representing the entire game in short
/// algebraic notation, with line breaks. Used when exporting PGNs.

- (NSString *)pgnMoveListString {
   Move line[800];
   int i = 0;

   for (ChessMove *move in moves)
      line[i++] = [move move];
   line[i] = MOVE_NONE;
   return
      breakLinesInString([NSString
                            stringWithUTF8String:
                               line_to_san(*startPosition, line, 0, false, 1).c_str()]);
}


/// pgnString returns an NSString representing the entire game as PGN.

- (NSString *)pgnString {
   NSMutableString *string = [NSMutableString stringWithCapacity: 2000];
   [string appendFormat: @"[Event \"%@\"]\n", event];
   [string appendFormat: @"[Site \"%@\"]\n", site];
   [string appendFormat: @"[Date \"%@\"]\n", date];
   [string appendFormat: @"[Round \"%@\"]\n", round];
   [string appendFormat: @"[White \"%@\"]\n", whitePlayer];
   [string appendFormat: @"[Black \"%@\"]\n", blackPlayer];
   [string appendFormat: @"[Result \"%@\"]\n", result];
   if (![startFEN isEqualToString: @"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"])
      [string appendFormat: @"[FEN \"%@\"]\n", startFEN];
   [string appendString: @"\n"];
   [string appendString: [self pgnMoveListString]];
   [string appendFormat: @"\n%@\n\n", [self result]];
   return string;
}


/// uciGameString returns a string representing the game in a format suitable
/// for input to an UCI engine, e.g. "position startpos moves e2e4 e7e5 ..."

- (NSString *)uciGameString {
   NSMutableString *buf = [NSMutableString stringWithCapacity: 4000];

   [buf setString: [NSString stringWithFormat: @"position fen %@", startFEN]];
   if (![self atBeginning]) {
      int i;
      Move m;
      [buf appendString: @" moves"];
      for (i = 0; i < currentMoveIndex; i++) {
         m = [[moves objectAtIndex: i] move];
         [buf appendFormat: @" %s", move_to_string(m).c_str()];
      }
   }
   return [NSString stringWithString: buf];
}


- (Move)moveFromString:(NSString *)string {
   return move_from_string(*currentPosition, [string UTF8String]);
}


- (BOOL)positionIsMate {
   return currentPosition->is_mate();
}


- (BOOL)positionIsDraw {
   return currentPosition->is_immediate_draw();
}


- (NSString *)drawReason {
   switch(currentPosition->is_immediate_draw()) {

   case DRAW_MATERIAL:
      return @"No mating material";
   case DRAW_50_MOVES:
      return @"50 non-reversible moves";
   case DRAW_REPETITION:
      return @"Third repetition";
   case DRAW_STALEMATE:
      return @"Stalemate";
   default:
      assert(NO);
      return nil;
   }
}


- (BOOL)positionIsTerminal {
   return [self positionIsMate] || [self positionIsDraw];
}


- (BOOL)positionAfterMoveIsTerminal:(Move)m {
   UndoInfo u;
   BOOL term;
   currentPosition->do_move(m, u);
   term = [self positionIsTerminal];
   currentPosition->undo_move(m, u);
   return term;
}


- (void)addComment:(NSString *)comment {
}


- (Move)currentMove {
   if (currentMoveIndex > 0)
      return [[moves objectAtIndex: currentMoveIndex-1] move];
   else
      return MOVE_NONE;
}


- (NSString *)currentFEN {
   return [NSString stringWithUTF8String: currentPosition->to_fen().c_str()];
}


/// Clean up.

- (void)dealloc {
   delete startPosition;
   delete currentPosition;

   [startFEN release];
   [moves release];
   [event release];
   [site release];
   [date release];
   [round release];
   [whitePlayer release];
   [blackPlayer release];
   [result release];

   [super dealloc];
}

@end
