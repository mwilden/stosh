/*
  Stockfish, a chess program for the Apple iPhone.
  Copyright (C) 2004-2010 Tord Romstad, Marco Costalba, Joona Kiiski.

  Stockfish is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Stockfish is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "EngineController.h"
#import "GameController.h"
#import "LastMoveView.h"
#import "MoveListView.h"
#import "Options.h"
#import "PieceImageView.h"
#import "PGN.h"
#import "RemoteEngineController.h"

#include "../Chess/misc.h"

using namespace Chess;

@implementation GameController

@synthesize whiteClockView, blackClockView, searchStatsView, game, rotated;
@dynamic gameMode;

- (id)initWithBoardView:(BoardView *)bv
           moveListView:(MoveListView *)mlv
           analysisView:(UILabel *)av
          bookMovesView:(UILabel *)bmv
         whiteClockView:(UILabel *)wcv
         blackClockView:(UILabel *)bcv
        searchStatsView:(UILabel *)ssv {
   if (self == [super init]) {
      boardView = bv;
      moveListView = mlv;
      analysisView = av;
      bookMovesView = bmv;
      whiteClockView = wcv;
      blackClockView = bcv;
      searchStatsView = ssv;

      game = [[Game alloc] initWithGameController: self];
      pieceViews = [[NSMutableArray alloc] init];
      pendingFrom = SQ_NONE;
      pendingTo = SQ_NONE;
      rotated = NO;
      gameLevel = [[Options sharedOptions] gameLevel];
      gameMode = [[Options sharedOptions] gameMode];
      engineIsPlaying = NO;

      [[NSNotificationCenter defaultCenter]
         addObserver: self
            selector: @selector(pieceSetChanged:)
                name: @"StockfishPieceSetChanged"
              object: nil];

      // Load sounds (only a click sound for now):
      id sndpath = [[NSBundle mainBundle] pathForResource: @"Click"
                                                   ofType: @"wav"
                                              inDirectory: @"/"];
      CFURLRef baseURL = (CFURLRef)[[NSURL alloc] initFileURLWithPath: sndpath];
      AudioServicesCreateSystemSoundID(baseURL, &clickSound);

      engineController = nil;
      remoteEngineController = [[RemoteEngineController alloc]
                                  initWithGameController: self];
      isPondering = NO;
   }
   return self;
}


- (void)startEngine {
   engineController = [[EngineController alloc] initWithGameController: self];
   [engineController sendCommand: @"uci"];
   [engineController sendCommand: @"isready"];
   [engineController sendCommand: @"ucinewgame"];
   [engineController sendCommand:
                        [NSString stringWithFormat:
                                     @"setoption name Play Style value %@",
                                  [[Options sharedOptions] playStyle]]];
   if ([[Options sharedOptions] permanentBrain])
      [engineController sendCommand: @"setoption name Ponder value true"];
   else
      [engineController sendCommand: @"setoption name Ponder value false"];

   if ([[Options sharedOptions] strength] == 2500) // Max strength
      [engineController
         sendCommand: @"setoption name UCI_LimitStrength value false"];
   else
      [engineController
         sendCommand: @"setoption name UCI_LimitStrength value true"];
   [engineController sendCommand:
                        [NSString stringWithFormat:
                                     @"setoption name UCI_Elo value %d",
                                  [[Options sharedOptions] strength]]];

   [engineController commitCommands];

   [self showBookMoves];
}


- (Square)rotateSquare:(Square)sq {
   return rotated? Square(SQ_H8 - sq) : sq;
}


/// startNewGame starts a new game, and discards the old one.  Later, we should
/// bring up some dialog to let the user choose time controls, colors etc.
/// before starting the new game.

- (void)startNewGame {
   NSLog(@"startNewGame");
   [game release];

   [boardView hideLastMove];
   [boardView stopHighlighting];

   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];

   game = [[Game alloc] initWithGameController: self];
   gameLevel = [[Options sharedOptions] gameLevel];
   gameMode = [[Options sharedOptions] gameMode];
   if ([[Options sharedOptions] isFixedTimeLevel])
      [game setTimeControlWithFixedTime: [[Options sharedOptions] timeIncrement]];
   else
      [game setTimeControlWithTime: [[Options sharedOptions] baseTime]
                         increment: [[Options sharedOptions] timeIncrement]];

   [game setWhitePlayer:
            ((gameMode == GAME_MODE_COMPUTER_BLACK)?
             [[[Options sharedOptions] fullUserName] copy] : ENGINE_NAME)];
   [game setBlackPlayer:
            ((gameMode == GAME_MODE_COMPUTER_BLACK)?
             ENGINE_NAME : [[[Options sharedOptions] fullUserName] copy])];

   pieceViews = [[NSMutableArray alloc] init];
   pendingFrom = SQ_NONE;
   pendingTo = SQ_NONE;

   [moveListView setText: @""];
   [analysisView setText: @""];
   [searchStatsView setText: @""];
   [self showPiecesAnimate: NO];
   engineIsPlaying = NO;
   [engineController abortSearch];
   [engineController sendCommand: @"ucinewgame"];
   [engineController sendCommand:
                        [NSString stringWithFormat:
                                     @"setoption name Play Style value %@",
                                  [[Options sharedOptions] playStyle]]];

   if ([[Options sharedOptions] strength] == 2500) // Max strength
      [engineController
         sendCommand: @"setoption name UCI_LimitStrength value false"];
   else
      [engineController
         sendCommand: @"setoption name UCI_LimitStrength value true"];

   [engineController commitCommands];

   if ([remoteEngineController isConnected])
      [remoteEngineController sendToServer: @"n\n"];

   [self showBookMoves];

   // Rotate board if the engine plays white:
   if (!rotated && [self computersTurnToMove])
      [self rotateBoard];
   [self engineGo];
}


- (void)updateMoveList {
   // Scroll to the end of move list.
   float height = [moveListView frame].size.height;
   if ([game atEnd]) {
      [moveListView setText: [game moveListString]];
      if ([moveListView contentSize].height > height)
         [moveListView
            setContentOffset:
               CGPointMake(0.0f, [moveListView contentSize].height - (height+3))];
   }
   else {
      [moveListView setText: [game partialMoveListString]];
      if ([moveListView contentSize].height > height)
         [moveListView
            setContentOffset:
               CGPointMake(0.0f, [moveListView contentSize].height - (height+3))];
      [moveListView setText: [game moveListString]];
   }
}


/// UIActionSheet delegate method for handling menu button choices.

- (void)actionSheet:(UIActionSheet *)actionSheet
clickedButtonAtIndex:(NSInteger)buttonIndex {
   if ([[actionSheet title] isEqualToString: @"Promote to"]) {
      // The ugly promotion menu. Promotions are handled by a truly hideous
      // hack, see a comment in the doMoveFrom:to:promotion function for an
      // explanation.
      static const PieceType prom[4] = { QUEEN, ROOK, KNIGHT, BISHOP };
      assert(buttonIndex >= 0 && buttonIndex < 4);
      [actionSheet release];
      [self doMoveFrom: pendingFrom to: pendingTo promotion: prom[buttonIndex]];
   }
   else if ([[actionSheet title] isEqualToString: @"Promote to:"]) {
      // Another ugly hack: We use a colon at the end of the string to
      // distinguish between promotions in the two move input methods.
      static const PieceType prom[4] = { QUEEN, ROOK, KNIGHT, BISHOP };
      assert(buttonIndex >= 0 && buttonIndex < 4);
      [actionSheet release];

      Move m = make_promotion_move(pendingFrom, pendingTo, prom[buttonIndex]);
      [self animateMove: m];
      [game doMove: m];

      if ([remoteEngineController isConnected])
         [remoteEngineController
            sendToServer: [NSString stringWithFormat: @"m %s\n",
                                    move_to_string(m).c_str()]];

      [self updateMoveList];
      [self showBookMoves];
      [self playClickSound];
      [self gameEndTest];
      [self engineGo];
   }
}


/// moveIsPending tests if there is a pending move waiting for the user to
/// choose the promotion piece. Related to the hideous hack in
/// doMoveFrom:to:promotion.

- (BOOL)moveIsPending {
   return pendingFrom != SQ_NONE;
}

- (Piece)pieceOn:(Square)sq {
   assert(square_is_ok(sq));
   return [game pieceOn: [self rotateSquare: sq]];
}


- (BOOL)pieceCanMoveFrom:(Square)sq {
   assert(square_is_ok(sq));
   return [game pieceCanMoveFrom: [self rotateSquare: sq]];
}


- (int)pieceCanMoveFrom:(Square)fSq to:(Square)tSq {

   fSq = [self rotateSquare: fSq];
   tSq = [self rotateSquare: tSq];

   // If the squares are invalid, the move can't be legal.
   if (!square_is_ok(fSq) || !square_is_ok(tSq))
      return 0;

   // Make sure we don't capture a friendly piece. This is important, because
   // of the way castling moves are encoded.
   if (color_of_piece([game pieceOn: tSq]) == color_of_piece([game pieceOn: fSq]))
      return 0;

   // HACK: Castling. The user probably tries to move the king two squares to
   // the side when castling, but Stockfish internally encodes castling moves
   // as "king captures rook". We handle this by adjusting tSq when the user
   // tries to move the king two squares to the side:
   if (fSq == SQ_E1 && tSq == SQ_G1 && [game pieceOn: fSq] == WK)
      tSq = SQ_H1;
   else if (fSq == SQ_E1 && tSq == SQ_C1 && [game pieceOn: fSq] == WK)
      tSq = SQ_A1;
   else if (fSq == SQ_E8 && tSq == SQ_G8 && [game pieceOn: fSq] == BK)
      tSq = SQ_H8;
   else if (fSq == SQ_E8 && tSq == SQ_C8 && [game pieceOn: fSq] == BK)
      tSq = SQ_A8;

   return [game pieceCanMoveFrom: fSq to: tSq];
}


/// destinationSquaresFrom:saveInArray takes a square and a C array of squares
/// as input, finds all squares the piece on the given square can move to,
/// and stores these possible destination squares in the array. This is used
/// in the GUI in order to highlight the squares a piece can move to.

- (int)destinationSquaresFrom:(Square)sq saveInArray:(Square *)sqs {
   int i, j, n;
   Move mlist[32];

   assert(square_is_ok(sq));
   assert(sqs != NULL);

   sq = [self rotateSquare: sq];

   n = [game movesFrom: sq saveInArray: mlist];
   for (i = 0, j = 0; i < n; i++)
      // Only include non-promotions and queen promotions, in order to avoid
      // having the same destination squares multiple times in the array.
      if (!move_promotion(mlist[i]) || move_promotion(mlist[i]) == QUEEN) {
         // For castling moves, adjust the destination square so that it displays
         // correctly when squares are highlighted in the GUI.
         if (move_is_long_castle(mlist[i]))
            sqs[j] = [self rotateSquare: move_to(mlist[i]) + 2];
         else if (move_is_short_castle(mlist[i]))
            sqs[j] = [self rotateSquare: move_to(mlist[i]) - 1];
         else
            sqs[j] = [self rotateSquare: move_to(mlist[i])];
         j++;
      }
   sqs[j] = SQ_NONE;
   return j;
}


/// doMoveFrom:to:promotion executes a move made by the user, and is called by
/// touchesEnded:withEvent in the PieceImageView class. Legality is checked
/// by that method, so at present we can safely assume that the move is legal.
/// Update the game, and do necessary updates to the board view (remove
/// captured pieces, move rook in case of castling).

- (void)doMoveFrom:(Square)fSq to:(Square)tSq promotion:(PieceType)prom {
   assert(square_is_ok(fSq));
   assert(square_is_ok(tSq));

   fSq = [self rotateSquare: fSq];
   tSq = [self rotateSquare: tSq];

   if ([game pieceCanMoveFrom: fSq to: tSq] > 1 && prom == NO_PIECE_TYPE) {
      // More than one legal move between the two squares. This means that the
      // user tries to do a promotion move, even though the "prom" parameter
      // doesn't say so. Handling this is really messy, because the iPhone SDK
      // doesn't seem to have anything equivalent to Cocoa's NSAlert() function.
      // What we really want to do is to bring up a modal dialog and stopping
      // until the user chooses a piece to promote to. This doesn't seem to be
      // possible: When the user chooses a menu option, the delegate method.
      // actionSheet:clickedButtonAtIndex: function is called, and control never
      // returns to the present function.
      //
      // We hack around this problem by remembering fSq and tSq, and calling
      // doMoveFrom:to:promotion again with the remembered values and the chosen
      // promotion piece from the delegate method. This is really ugly.  :-(
      pendingFrom = [self rotateSquare: fSq];
      pendingTo = [self rotateSquare: tSq];
      UIActionSheet *menu =
         [[UIActionSheet alloc]
            initWithTitle: @"Promote to"
                 delegate: self
            cancelButtonTitle: nil
            destructiveButtonTitle: nil
            otherButtonTitles: @"Queen", @"Rook", @"Knight", @"Bishop", nil];
      [menu showInView: [boardView superview]];
      return;
   }

   // HACK: Castling. The user probably tries to move the king two squares to
   // the side when castling, but Stockfish internally encodes castling moves
   // as "king captures rook". We handle this by adjusting tSq when the user
   // tries to move the king two squares to the side:
   static const int woo = 1, wooo = 2, boo = 3, booo = 4;
   int castle = 0;
   if (fSq == SQ_E1 && tSq == SQ_G1 && [game pieceOn: fSq] == WK) {
      tSq = SQ_H1; castle = woo;
   } else if (fSq == SQ_E1 && tSq == SQ_C1 && [game pieceOn: fSq] == WK) {
      tSq = SQ_A1; castle = wooo;
   } else if (fSq == SQ_E8 && tSq == SQ_G8 && [game pieceOn: fSq] == BK) {
      tSq = SQ_H8; castle = boo;
   } else if (fSq == SQ_E8 && tSq == SQ_C8 && [game pieceOn: fSq] == BK) {
      tSq = SQ_A8; castle = booo;
   }

   if (castle) {
      // Move the rook.
      PieceImageView *piv;
      Square rsq;

      if (castle == woo) {
         piv = [self pieceImageViewForSquare: SQ_H1];
         rsq = [self rotateSquare: SQ_F1];
      }
      else if (castle == wooo) {
         piv = [self pieceImageViewForSquare: SQ_A1];
         rsq = [self rotateSquare: SQ_D1];
      }
      else if (castle == boo) {
         piv = [self pieceImageViewForSquare: SQ_H8];
         rsq = [self rotateSquare: SQ_F8];
      }
      else if (castle == booo) {
         piv = [self pieceImageViewForSquare: SQ_A8];
         rsq = [self rotateSquare: SQ_D8];
      }
      else
         assert(false);
      [piv moveToSquare: rsq];
   }
   else if ([game pieceOn: tSq] != EMPTY)
      // Capture. Remove captured piece.
      [self removePieceOn: tSq];
   else if (type_of_piece([game pieceOn: fSq]) == PAWN
            && square_file(tSq) != square_file(fSq)) {
      // Pawn moves to a different file, and destination square is empty. This
      // must be an en passant capture. Remove captured pawn:
      Square epSq = tSq - pawn_push([game sideToMove]);
      assert([game pieceOn: epSq]
             == pawn_of_color(opposite_color([game sideToMove])));
      [self removePieceOn: epSq];
   }

   // In case of promotion, update the piece image view.
   if (prom) {
      [self removePieceOn: fSq];
      [self putPiece: piece_of_color_and_type([game sideToMove], prom)
                  on: tSq];
   }

   // Update the game and move list:
   Move m = [game doMoveFrom: fSq to: tSq promotion: prom];
   if ([remoteEngineController isConnected])
      [remoteEngineController
         sendToServer: [NSString stringWithFormat: @"m %s\n",
                                 move_to_string(m).c_str()]];
   [self updateMoveList];
   [self showBookMoves];
   pendingFrom = pendingTo = SQ_NONE;

   // Play a click sound when the move has been made.
   [self playClickSound];

   // Game over?
   [self gameEndTest];

   // Clear the search stats view
   [searchStatsView setText: @""];

   // HACK to handle promotions
   if (prom)
      [self engineGo];
}


- (void)promotionMenu {
   [[[UIActionSheet alloc]
       initWithTitle: @"Promote to:"
            delegate: self
       cancelButtonTitle: nil
       destructiveButtonTitle: nil
       otherButtonTitles: @"Queen", @"Rook", @"Knight", @"Bishop", nil]
      showInView: [boardView superview]];
}


- (void)animateMoveFrom:(Square)fSq to:(Square)tSq {
   assert(square_is_ok(fSq));
   assert(square_is_ok(tSq));

   fSq = [self rotateSquare: fSq];
   tSq = [self rotateSquare: tSq];

   if ([game pieceCanMoveFrom: fSq to: tSq] > 1) {
      pendingFrom = fSq;
      pendingTo = tSq;
      [self promotionMenu];
      return;
   }

   // HACK: Castling. The user probably tries to move the king two squares to
   // the side when castling, but Stockfish internally encodes castling moves
   // as "king captures rook". We handle this by adjusting tSq when the user
   // tries to move the king two squares to the side:
   static const int woo = 1, wooo = 2, boo = 3, booo = 4;
   int castle = 0;
   BOOL ep = NO;
   if (fSq == SQ_E1 && tSq == SQ_G1 && [game pieceOn: fSq] == WK) {
      tSq = SQ_H1; castle = woo;
   } else if (fSq == SQ_E1 && tSq == SQ_C1 && [game pieceOn: fSq] == WK) {
      tSq = SQ_A1; castle = wooo;
   } else if (fSq == SQ_E8 && tSq == SQ_G8 && [game pieceOn: fSq] == BK) {
      tSq = SQ_H8; castle = boo;
   } else if (fSq == SQ_E8 && tSq == SQ_C8 && [game pieceOn: fSq] == BK) {
      tSq = SQ_A8; castle = booo;
   }
   else if (type_of_piece([game pieceOn: fSq]) == PAWN &&
            [game pieceOn: tSq] == EMPTY &&
            square_file(fSq) != square_file(tSq))
      ep = YES;

   Move m;
   if (castle)
      m = make_castle_move(fSq, tSq);
   else if (ep)
      m = make_ep_move(fSq, tSq);
   else
      m = make_move(fSq, tSq);

   [self animateMove: m];
   [game doMove: m];

   if ([remoteEngineController isConnected])
      [remoteEngineController
         sendToServer: [NSString stringWithFormat: @"m %s\n",
                                 move_to_string(m).c_str()]];

   [self updateMoveList];
   [self showBookMoves];
   [self playClickSound];
   [self gameEndTest];
   [self engineGo];
}


/// removePieceOn: removes a piece from the board view.  The piece is
/// assumed to still be present on the board in the current position
/// in the game: The method is called directly before a captured piece
/// is removed from the game board.

- (void)removePieceOn:(Square)sq {
   sq = [self rotateSquare: sq];
   assert(square_is_ok(sq));
   for (int i = 0; i < [pieceViews count]; i++)
      if ([[pieceViews objectAtIndex: i] square] == sq) {
         [[pieceViews objectAtIndex: i] removeFromSuperview];
         [pieceViews removeObjectAtIndex: i];
         break;
      }
}


/// putPiece:on: inserts a new PieceImage subview to the board view. This method
/// is called when the user takes back a capturing move.

- (void)putPiece:(Piece)p on:(Square)sq {
   assert(piece_is_ok(p));
   assert(square_is_ok(sq));

   sq = [self rotateSquare: sq];

   float sqSize = [boardView sqSize];
   CGRect rect = CGRectMake(0.0f, 0.0f, sqSize, sqSize);
   rect.origin = CGPointMake((int(sq)%8) * sqSize, (7-int(sq)/8) * sqSize);
   PieceImageView *piv = [[PieceImageView alloc] initWithFrame: rect
                                                gameController: self
                                                     boardView: boardView];
   [piv setImage: pieceImages[p]];
   [piv setUserInteractionEnabled: YES];
   [piv setAlpha: 0.0];
   [boardView addSubview: piv];
   [pieceViews addObject: piv];

   CGContextRef context = UIGraphicsGetCurrentContext();
   [UIView beginAnimations: nil context: context];
   [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
   [UIView setAnimationDuration: 0.25];
   [piv setAlpha: 1.0];
   [UIView commitAnimations];

   [piv release];
}


/// takeBackMove takes back the last move played, unless we are at the beginning
/// of the game, in which case nothing happens. Both the game and the board view
/// are updated. We should maybe highlight the current move in the move list,
/// too, but this seems tricky.

- (void)takeBackMove {
   if (![game atBeginning]) {
      ChessMove *cm = [game previousMove];
      Square from = move_from([cm move]), to = move_to([cm move]);
      UndoInfo ui = [cm undoInfo];

      // If the engine is pondering, stop it before unmaking the move.
      if (isPondering) {
         NSLog(@"pondermiss because of take back");
         [engineController pondermiss];
         isPondering = NO;
      }

      // HACK: Castling. Stockfish internally encodes castling moves as "king
      // captures rook", which means that the "to" square does not contain the
      // king's current square on the board. Adjust the "to" square, and check
      // what sort of castling move it is, to help us move the rook back home
      // later.
      static const int woo = 1, wooo = 2, boo = 3, booo = 4;
      int castle = 0;
      if (move_is_short_castle([cm move])) {
         castle = ([game sideToMove] == BLACK)? woo : boo;
         to = ([game sideToMove] == BLACK)? SQ_G1 : SQ_G8;
      }
      else if (move_is_long_castle([cm move])) {
         castle = ([game sideToMove] == BLACK)? wooo : booo;
         to = ([game sideToMove] == BLACK)? SQ_C1 : SQ_C8;
      }

      // In case of promotion, unpromote the piece before moving it back:
      if (move_promotion([cm move]))
         [[self pieceImageViewForSquare: to]
            setImage: pieceImages[pawn_of_color(opposite_color([game sideToMove]))]];

      // Put the moving piece back at its source square:
      [[self pieceImageViewForSquare: to] moveToSquare:
                                    [self rotateSquare: from]];

      // For castling moves, move the rook back:
      if (castle == woo)
         [[self pieceImageViewForSquare: SQ_F1]
            moveToSquare: [self rotateSquare: SQ_H1]];
      else if (castle == wooo)
         [[self pieceImageViewForSquare: SQ_D1]
            moveToSquare: [self rotateSquare: SQ_A1]];
      else if (castle == boo)
         [[self pieceImageViewForSquare: SQ_F8]
            moveToSquare: [self rotateSquare: SQ_H8]];
      else if (castle == booo)
         [[self pieceImageViewForSquare: SQ_D8]
            moveToSquare: [self rotateSquare: SQ_A8]];

      // In the case of a capture, put the captured piece back on the board.
      if (move_is_ep([cm move]))
         [self putPiece: pawn_of_color([game sideToMove])
                     on: to + pawn_push([game sideToMove])];
      else if (ui.capture)
         [self putPiece: piece_of_color_and_type([game sideToMove], ui.capture)
                     on: to];

      // Don't show the last move played any more:
      [boardView hideLastMove];
      [boardView stopHighlighting];

      // Stop engine:
      if ([self computersTurnToMove]) {
         engineIsPlaying = NO;
         [engineController abortSearch];
         [engineController commitCommands];
      }

      // Update remote engine:
      if ([remoteEngineController isConnected]) {
         //[remoteEngineController sendToServer: @"s\n"];  // Stop search
         [remoteEngineController sendToServer: @"t\n"];  // Take back
      }

      // Update the game:
      [game takeBack];

      // If in analyse mode, send new position to engine, and tell it to start
      // thinking:
      if (gameMode == GAME_MODE_ANALYSE && ![game positionIsTerminal]) {
         if (![remoteEngineController isConnected]) {
            [engineController abortSearch];
            [engineController sendCommand: [game uciGameString]];
            [engineController sendCommand: @"go infinite"];
            [engineController commitCommands];
         }
         else {
            [remoteEngineController sendToServer: @"gi\n"];
         }
      }

      // Stop the clock:
      [game stopClock];
   }
   [self updateMoveList];
   [self showBookMoves];
}


- (void)takeBackAllMoves {
   if (![game atBeginning]) {

      [boardView hideLastMove];
      [boardView stopHighlighting];

      // Release piece images
      for (PieceImageView *piv in pieceViews)
         [piv removeFromSuperview];
      [pieceViews release];

      // Update game
      [game toBeginning];

      // Update board
      pieceViews = [[NSMutableArray alloc] init];
      [self showPiecesAnimate: NO];

      // Stop engine:
      if ([self computersTurnToMove]) {
         engineIsPlaying = NO;
         [engineController abortSearch];
         [engineController commitCommands];
      }

      // Update remote engine:
      if ([remoteEngineController isConnected]) {
         //[remoteEngineController sendToServer: @"s\n"];  // Stop search
         [remoteEngineController sendToServer: @"b\n"];  // Go to beginning of game
      }

      // If in analyse mode, send new position to engine, and tell it to start
      // thinking:
      if (gameMode == GAME_MODE_ANALYSE && ![game positionIsTerminal]) {
         if (![remoteEngineController isConnected]) {
            [engineController abortSearch];
            [engineController sendCommand: [game uciGameString]];
            [engineController sendCommand: @"go infinite"];
            [engineController commitCommands];
         }
         else {
            [remoteEngineController sendToServer: @"gi\n"];
         }
      }

      // Stop the clock:
      [game stopClock];

      [self updateMoveList];
      [self showBookMoves];
   }
}


- (void)animateMove:(Move)m {
   Square from = move_from(m), to = move_to(m);

   // HACK: Castling. Stockfish internally encodes castling moves as "king
   // captures rook", which means that the "to" square does not contain the
   // king's current square on the board. Adjust the "to" square, and check
   // what sort of castling move it is, to help us move the rook later.
   static const int woo = 1, wooo = 2, boo = 3, booo = 4;
   int castle = 0;
   if (move_is_short_castle(m)) {
      castle = ([game sideToMove] == WHITE)? woo : boo;
      to = ([game sideToMove] == WHITE)? SQ_G1 : SQ_G8;
   }
   else if (move_is_long_castle(m)) {
      castle = ([game sideToMove] == WHITE)? wooo : booo;
      to = ([game sideToMove] == WHITE)? SQ_C1 : SQ_C8;
   }

   // In the case of a capture, remove the captured piece.
   if ([game pieceOn: to] != EMPTY)
      [self removePieceOn: to];
   else if (move_is_ep(m))
      [self removePieceOn: to - pawn_push([game sideToMove])];

   // Move the piece
   [[self pieceImageViewForSquare: from] moveToSquare:
                                   [self rotateSquare: to]];

   // If move is promotion, update the piece image:
   if (move_promotion(m))
      [[self pieceImageViewForSquare: to]
         setImage:
            pieceImages[piece_of_color_and_type([game sideToMove],
                                                move_promotion(m))]];

   // If move is a castle, move the rook
   if (castle == woo)
      [[self pieceImageViewForSquare: SQ_H1]
         moveToSquare: [self rotateSquare: SQ_F1]];
   else if (castle == wooo)
      [[self pieceImageViewForSquare: SQ_A1]
         moveToSquare: [self rotateSquare: SQ_D1]];
   else if (castle == boo)
      [[self pieceImageViewForSquare: SQ_H8]
         moveToSquare: [self rotateSquare: SQ_F8]];
   else if (castle == booo)
      [[self pieceImageViewForSquare: SQ_A8]
         moveToSquare: [self rotateSquare: SQ_D8]];
}


/// replayMove steps forward one move in the game, unless we are at the end of
/// the game, in which case nothing happens. Both the game and the board view
/// are updated. We should maybe highlight the current move in the move list,
/// too, but this seems tricky.

- (void)replayMove {
   if (![game atEnd]) {
      ChessMove *cm = [game nextMove];

      [self animateMove: [cm move]];

      // Update the game:
      [game stepForward];

      // Don't show the last move played any more:
      [boardView hideLastMove];
      [boardView stopHighlighting];

      // Update remote engine:
      if ([remoteEngineController isConnected]) {
         //[remoteEngineController sendToServer: @"s\n"];  // Stop search
         [remoteEngineController sendToServer: @"f\n"];  // Step forward
      }

      // If in analyse mode, send new position to engine, and tell it to start
      // thinking:
      if (gameMode == GAME_MODE_ANALYSE && ![game positionIsTerminal]) {
         if (![remoteEngineController isConnected]) {
            [engineController abortSearch];
            [engineController sendCommand: [game uciGameString]];
            [engineController sendCommand: @"go infinite"];
            [engineController commitCommands];
         }
         else {
            [remoteEngineController sendToServer: @"gi\n"]; // Start new search
         }
      }
   }
   [self updateMoveList];
   [self showBookMoves];
}


- (void)replayAllMoves {
   if (![game atEnd]) {

      [boardView hideLastMove];
      [boardView stopHighlighting];

      // Release piece images
      for (PieceImageView *piv in pieceViews)
         [piv removeFromSuperview];
      [pieceViews release];

      // Update game
      [game toEnd];

      // Update board
      pieceViews = [[NSMutableArray alloc] init];
      [self showPiecesAnimate: NO];

      // Stop engine:
      if ([self computersTurnToMove]) {
         engineIsPlaying = NO;
         [engineController abortSearch];
         [engineController commitCommands];
      }

      // Update remote engine:
      if ([remoteEngineController isConnected]) {
         //[remoteEngineController sendToServer: @"s\n"]; // Stop search
         [remoteEngineController sendToServer: @"e\n"]; // Go to end of game
      }

      // If in analyse mode, send new position to engine, and tell it to start
      // thinking:
      if (gameMode == GAME_MODE_ANALYSE && ![game positionIsTerminal]) {
         if (![remoteEngineController isConnected]) {
            [engineController abortSearch];
            [engineController sendCommand: [game uciGameString]];
            [engineController sendCommand: @"go infinite"];
            [engineController commitCommands];
         }
         else {
            [remoteEngineController sendToServer: @"gi\n"];
         }
      }

      // Stop the clock:
      [game stopClock];

      [self updateMoveList];
      [self showBookMoves];
   }
}


/// showPiecesAnimate: creates the piece image views and attaches them as
/// subviews to the board view.  There is a boolean parameter which tells
/// the method whether the pieces should appear gradually or instantly.

- (void)showPiecesAnimate:(BOOL)animate {
   float sqSize = [boardView sqSize];
   CGRect rect = CGRectMake(0.0f, 0.0f, sqSize, sqSize);
   for (Square sq = SQ_A1; sq <= SQ_H8; sq++) {
      Square s = [self rotateSquare: sq];
      Piece p = [self pieceOn: s];
      if (p != EMPTY) {
         assert(piece_is_ok(p));
         rect.origin = CGPointMake((int(s)%8) * sqSize, (7-int(s)/8) * sqSize);
         PieceImageView *piv = [[PieceImageView alloc] initWithFrame: rect
                                                      gameController: self
                                                           boardView: boardView];
         [piv setImage: pieceImages[p]];
         [piv setUserInteractionEnabled: YES];
         [piv setAlpha: 0.0];
         [boardView addSubview: piv];
         [pieceViews addObject: piv];
         [piv release];
      }
   }
   if (animate) {
      CGContextRef context = UIGraphicsGetCurrentContext();
      [UIView beginAnimations: nil context: context];
      [UIView setAnimationCurve: UIViewAnimationCurveEaseInOut];
      [UIView setAnimationDuration: 1.2];
      for (PieceImageView *piv in pieceViews)
         [piv setAlpha: 1.0];
      [UIView commitAnimations];
   }
   else
      for (PieceImageView *piv in pieceViews)
         [piv setAlpha: 1.0];
}


- (PieceImageView *)pieceImageViewForSquare:(Square)sq {
   sq = [self rotateSquare: sq];
   for (PieceImageView *piv in pieceViews)
      if ([piv square] == sq)
         return piv;
   return nil;
}


- (void)rotateBoard {
   rotated = !rotated;
   for (PieceImageView *piv in pieceViews)
      [piv moveToSquare: Square(SQ_H8 - [piv square])];
   [boardView hideLastMove];
   [boardView stopHighlighting];
}


- (void)rotateBoard:(BOOL)rotate {
   if (rotate != rotated)
      [self rotateBoard];
}


/// showHint displays a suggestion for a good move to the user. At the
/// moment, it just displays a random legal move.

- (void)showHint {
   if (gameMode == GAME_MODE_ANALYSE)
      [[[[UIAlertView alloc] initWithTitle: @"Hints are not available in analyse mode!"
                                   message: nil
                                  delegate: self
                         cancelButtonTitle: nil
                         otherButtonTitles: @"OK", nil] autorelease]
         show];
   else if (gameMode == GAME_MODE_TWO_PLAYER)
      [[[[UIAlertView alloc] initWithTitle: @"Hints are not available in two player mode!"
                                   message: nil
                                  delegate: self
                         cancelButtonTitle: nil
                         otherButtonTitles: @"OK", nil] autorelease]
         show];
   else {
      Move mlist[256], m;
      int n;
      n = [game generateLegalMoves: mlist];
      m = [game getBookMove];

      if (m == MOVE_NONE)
         m = [game getHintForCurrentPosition];

      if (m != MOVE_NONE) {
         Square to = move_to(m);
         if (move_is_long_castle(m)) to += 2;
         else if (move_is_short_castle(m)) to -= 1;
         [[self pieceImageViewForSquare: move_from(m)]
            moveToSquareAndBack: [self rotateSquare: to]];
      }
      else
         [[[[UIAlertView alloc] initWithTitle: @"No hint available!"
                                      message: nil
                                     delegate: self
                            cancelButtonTitle: nil
                            otherButtonTitles: @"OK", nil] autorelease]
            show];
   }
}


/// emailPgnString returns an NSString representing a mailto: URL with the
/// current game in PGN notation included in the body.
- (NSString *)emailPgnString {
   return [game emailPgnString];
}


- (void)playClickSound {
   if ([[Options sharedOptions] moveSound])
      AudioServicesPlaySystemSound(clickSound);
}

- (void)displayPV:(NSString *)pv {
   if ([[Options sharedOptions] showAnalysis]) {
      if ([[Options sharedOptions] figurineNotation]) {
         unichar c;
         NSString *s;
         NSString *pc[6] = { @"K", @"Q", @"R", @"B", @"N" };
         int i;
         for (i = 0, c = 0x2654; i < 5; i++, c++) {
            s = [NSString stringWithCharacters: &c length: 1];
            pv = [pv stringByReplacingOccurrencesOfString: pc[i] withString: s];
         }
      }
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
         [analysisView setText: [NSString stringWithFormat: @"  %@", pv]];
      else
         [analysisView setText: pv];
   }
   else
      [analysisView setText: @""];
}


- (void)displaySearchStats:(NSString *)searchStats {
   if ([[Options sharedOptions] showAnalysis]) {
      if ([[Options sharedOptions] figurineNotation]) {
         unichar c;
         NSString *s;
         NSString *pc[6] = { @"K", @"Q", @"R", @"B", @"N" };
         int i;
         for (i = 0, c = 0x2654; i < 5; i++, c++) {
            s = [NSString stringWithCharacters: &c length: 1];
            searchStats =
               [searchStats stringByReplacingOccurrencesOfString: pc[i]
                                                      withString: s
                                                         options: 0
                                                           range: NSMakeRange(0, 20)];
         }
      }
      [searchStatsView setText: searchStats];
   }
   else
      [searchStatsView setText: @""];
}


- (void)setGameLevel:(GameLevel)newGameLevel {
   NSLog(@"new game level: %d", newGameLevel);
   gameLevel = newGameLevel;
   if ([[Options sharedOptions] isFixedTimeLevel]) {
      NSLog(@"fixed time: %d", [[Options sharedOptions] timeIncrement]);
      [game setTimeControlWithFixedTime: [[Options sharedOptions] timeIncrement]];
   }
   else {
      NSLog(@"base time: %d increment: %d",
            [[Options sharedOptions] baseTime],
            [[Options sharedOptions] timeIncrement]);
      [game setTimeControlWithTime: [[Options sharedOptions] baseTime]
                         increment: [[Options sharedOptions] timeIncrement]];
   }
}

- (GameMode)gameMode {
   return gameMode;
}

- (void)setGameMode:(GameMode)newGameMode {
   NSLog(@"new game mode: %d", newGameMode);
   if (gameMode == GAME_MODE_ANALYSE && newGameMode != GAME_MODE_ANALYSE) {
      [engineController pondermiss]; // HACK
      [engineController sendCommand:
                           @"setoption name UCI_AnalyseMode value false"];
      [engineController commitCommands];
      if ([remoteEngineController isConnected])
         [remoteEngineController sendToServer: @"s\n"];
   }
   else if (isPondering) {
      NSLog(@"pondermiss because game mode changed while pondering");
      [engineController pondermiss];
      isPondering = NO;
   }
   [game setWhitePlayer:
            ((newGameMode == GAME_MODE_COMPUTER_BLACK)?
             [[[Options sharedOptions] fullUserName] copy] : ENGINE_NAME)];
   [game setBlackPlayer:
            ((newGameMode == GAME_MODE_COMPUTER_BLACK)?
             ENGINE_NAME : [[[Options sharedOptions] fullUserName] copy])];
   gameMode = newGameMode;

   // If in analyse mode, automatically switch on "Show analysis"
   if (gameMode == GAME_MODE_ANALYSE && ![remoteEngineController isConnected]) {
      [[Options sharedOptions] setShowAnalysis: YES];
      [[boardView superview] bringSubviewToFront: searchStatsView];
      [searchStatsView setNeedsDisplay];
   }
   else
      [[boardView superview] sendSubviewToBack: searchStatsView];

   // Rotate board if necessary:
   if ((gameMode == GAME_MODE_COMPUTER_WHITE && !rotated) ||
       (gameMode == GAME_MODE_COMPUTER_BLACK && rotated))
      [self rotateBoard];

   // Start thinking if necessary:
   [self engineGo];
}


- (void)doEngineMove:(Move)m {
   Square to = move_to(m);
   if (move_is_long_castle(m)) to += 2;
   else if (move_is_short_castle(m)) to -= 1;
   [boardView showLastMoveWithFrom: [self rotateSquare: move_from(m)]
                                to: [self rotateSquare: to]];

   [self animateMove: m];
   [game doMove: m];

   if ([remoteEngineController isConnected])
      [remoteEngineController
         sendToServer: [NSString stringWithFormat: @"m %s\n",
                                 move_to_string(m).c_str()]];

   [self updateMoveList];
   [self showBookMoves];
}


/// engineGo is called directly after the user has made a move.  It checks
/// the game mode, and sends a UCI "go" command to the engine if necessary.

- (void)engineGo {
   if (!engineController)
      [self startEngine];

   if (![game positionIsTerminal]) {
      if (gameMode == GAME_MODE_ANALYSE) {
         engineIsPlaying = NO;
         [engineController abortSearch];
         if (![remoteEngineController isConnected]) {
            [engineController sendCommand: [game uciGameString]];
            [engineController sendCommand:
                                 @"setoption name UCI_AnalyseMode value true"];
            [engineController sendCommand: @"go infinite"];
            [engineController commitCommands];
         }
         else {
            [remoteEngineController sendToServer: @"s\n"];
            [remoteEngineController sendToServer: @"gi\n"];
         }
         return;
      }
      if (isPondering) {
         if ([game currentMove] == ponderMove) {
            [engineController ponderhit];
            isPondering = NO;
            return;
         }
         else {
            NSLog(@"REAL pondermiss");
            [engineController pondermiss];
            while ([engineController engineIsThinking]);
         }
         isPondering = NO;
      }
      if ((gameMode==GAME_MODE_COMPUTER_BLACK && [game sideToMove]==BLACK) ||
          (gameMode==GAME_MODE_COMPUTER_WHITE && [game sideToMove]==WHITE)) {
         // Computer's turn to move.  First look for a book move.  If no book move
         // is found, start a search.
         Move m;
         if ([[Options sharedOptions] strength] > 2200 ||
             [game currentMoveIndex] < 10 ||
             [game currentMoveIndex] < [[Options sharedOptions] strength] / 70)
            m = [game getBookMove];
         else
            m = MOVE_NONE;
         if (m != MOVE_NONE)
            [self doEngineMove: m];
         else {
            // Update play style, if necessary
            if ([[Options sharedOptions] playStyleWasChanged]) {
               NSLog(@"play style was changed to: %@",
                     [[Options sharedOptions] playStyle]);
               [engineController sendCommand:
                                    [NSString stringWithFormat:
                                                 @"setoption name Play Style value %@",
                                              [[Options sharedOptions] playStyle]]];
               [engineController commitCommands];
            }
            // Update strength, if necessary
            if ([[Options sharedOptions] strengthWasChanged]) {
               [engineController sendCommand: @"setoption name Clear Hash"];
               if ([[Options sharedOptions] strength] == 2500) // Max strength
                  [engineController
                     sendCommand: @"setoption name UCI_LimitStrength value false"];
               else
                  [engineController
                     sendCommand: @"setoption name UCI_LimitStrength value true"];
               [engineController sendCommand:
                                    [NSString stringWithFormat:
                                                 @"setoption name UCI_Elo value %d",
                                              [[Options sharedOptions] strength]]];
               [engineController commitCommands];
            }
            // Start thinking.
            engineIsPlaying = YES;
            if (![remoteEngineController isConnected]) {
               [engineController sendCommand: [game uciGameString]];
               if ([[Options sharedOptions] isFixedTimeLevel])
                  [engineController
                     sendCommand: [NSString stringWithFormat: @"go movetime %d",
                                            [[Options sharedOptions] timeIncrement]]];
               else
                  [engineController
                     sendCommand: [NSString stringWithFormat: @"go wtime %d btime %d winc %d binc %d",
                                            [[game clock] whiteRemainingTime],
                                            [[game clock] blackRemainingTime],
                                            [[game clock] whiteIncrement],
                                            [[game clock] blackIncrement]]];
               [engineController commitCommands];
            }
            else {
               // TODO: Fixed time levels
               [remoteEngineController
                  sendToServer: [NSString stringWithFormat: @"go %d %d %d %d\n",
                                          [[game clock] whiteRemainingTime],
                                          [[game clock] whiteIncrement],
                                          [[game clock] blackRemainingTime],
                                          [[game clock] blackIncrement]]];
            }
         }
      }
   }
}


- (void)engineGoPonder:(Move)pMove {
   // TODO: Pondering with remote engine.
   if ([remoteEngineController isConnected])
      return;

   if (![game positionIsTerminal] && ![game positionAfterMoveIsTerminal: pMove]) {
      assert(engineIsPlaying);
      assert((gameMode==GAME_MODE_COMPUTER_BLACK && [game sideToMove]==WHITE) ||
             (gameMode==GAME_MODE_COMPUTER_WHITE && [game sideToMove]==BLACK));
      assert(pMove != MOVE_NONE);

      // Start thinking.
      engineIsPlaying = YES;
      [engineController
         sendCommand:
            [NSString stringWithFormat: @"%@ %s",
                      [game uciGameString], move_to_string(pMove).c_str()]];
      isPondering = YES;
      [engineController
         sendCommand: [NSString stringWithFormat: @"go ponder wtime %d btime %d winc %d binc %d",
                                [[game clock] whiteRemainingTime],
                                [[game clock] blackRemainingTime],
                                [[game clock] whiteIncrement],
                                [[game clock] blackIncrement]]];
      [engineController commitCommands];
   }
}


/// engineMadeMove: is called by the engine controller whenever the engine
/// makes a move.  The input is an NSArray which is assumed to consist of two
/// NSStrings, representing a move and a ponder move.  The reason we stuff the
/// move strings into an array is that the method is called from another thread,
/// using the performSelectorOnMainThread:withObject:waitUntilDone: method,
/// and this method can only pass a single argument to the selector.

- (void)engineMadeMove:(NSArray *)array {
   assert([array count] <= 2);
   Move m = [game moveFromString: [array objectAtIndex: 0]];
   assert(m != MOVE_NONE);
   [game setHintForCurrentPosition: m];
   if (engineIsPlaying) {
      [self doEngineMove: m];
      [self playClickSound];
      if ([array count] == 2) {
         ponderMove = [game moveFromString: [array objectAtIndex: 1]];
         [game setHintForCurrentPosition: ponderMove];
         if ([[Options sharedOptions] permanentBrain])
            [self engineGoPonder: ponderMove];
      }
      [self gameEndTest];
   }
}


- (BOOL)usersTurnToMove {
   return
      gameMode == GAME_MODE_TWO_PLAYER ||
      gameMode == GAME_MODE_ANALYSE ||
      (gameMode == GAME_MODE_COMPUTER_BLACK && [game sideToMove] == WHITE) ||
      (gameMode == GAME_MODE_COMPUTER_WHITE && [game sideToMove] == BLACK);
}


- (BOOL)computersTurnToMove {
   return ![self usersTurnToMove];
}


- (void)engineMoveNow {
   if ([self computersTurnToMove]) {
      if (![remoteEngineController isConnected]) {
         [engineController abortSearch];
         [engineController commitCommands];
      }
      else
         [remoteEngineController sendToServer: @"s\n"];
   }
}


- (void)gameEndTest {
   if ([game positionIsMate]) {
      [[[[UIAlertView alloc] initWithTitle: (([game sideToMove] == WHITE)?
                                             @"Black wins" : @"White wins")
                                   message: @"Checkmate!"
                                  delegate: self
                         cancelButtonTitle: nil
                         otherButtonTitles: @"OK", nil]
          autorelease]
         show];
      [game setResult: (([game sideToMove] == WHITE)? @"0-1" : @"1-0")];
   }
   else if ([game positionIsDraw]) {
      [[[[UIAlertView alloc] initWithTitle: @"Game drawn"
                                   message: [game drawReason]
                                  delegate: self
                         cancelButtonTitle: nil
                         otherButtonTitles: @"OK", nil]
          autorelease]
         show];
      [game setResult: @"1/2-1/2"];
   }
}


- (void)loadPieceImages {
   for (Piece p = WP; p <= BK; p++)
      [pieceImages[p] release];
   static NSString *pieceImageNames[16] = {
      nil, @"WPawn", @"WKnight", @"WBishop", @"WRook", @"WQueen", @"WKing", nil,
      nil, @"BPawn", @"BKnight", @"BBishop", @"BRook", @"BQueen", @"BKing", nil
   };
   NSString *pieceSet = [[Options sharedOptions] pieceSet];
   for (Piece p = WP; p <= BK; p++) {
      if (piece_is_ok(p)) {
         if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            pieceImages[p] =
               [[UIImage imageNamed: [NSString stringWithFormat: @"%@%@96.tiff",
                                               pieceSet, pieceImageNames[p]]]
                  retain];
         else
            pieceImages[p] =
               [[UIImage imageNamed: [NSString stringWithFormat: @"%@%@.tiff",
                                               pieceSet, pieceImageNames[p]]]
                  retain];
      }
      else
         pieceImages[p] = nil;
   }
}


- (void)pieceSetChanged:(NSNotification *)aNotification {
   [self loadPieceImages];
   for (Square sq = SQ_A1; sq <= SQ_H8; sq++) {
      Square s = [self rotateSquare: sq];
      if ([self pieceOn: s] != EMPTY) {
         PieceImageView *piv = [self pieceImageViewForSquare: sq];
         [piv setImage: pieceImages[[self pieceOn: s]]];
         [piv setNeedsDisplay];
      }
   }
}


- (void)gameFromPGNString:(NSString *)pgnString {
   [game release];
   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];

   @try {
      game = [[Game alloc] initWithGameController: self PGNString: pgnString];
   }
   @catch (NSException *e) {
      NSLog(@"Exception while parsing stored game: %@", [e reason]);
      NSLog(@"game:\n%@", pgnString);
      game = [[Game alloc] initWithGameController: self];
   }

   if ([remoteEngineController isConnected])
      [remoteEngineController sendToServer: [game remoteEngineGameString]];

   gameLevel = [[Options sharedOptions] gameLevel];
   gameMode = [[Options sharedOptions] gameMode];
   [game setTimeControlWithTime: [[Options sharedOptions] baseTime]
                      increment: [[Options sharedOptions] timeIncrement]];
   pieceViews = [[NSMutableArray alloc] init];
   pendingFrom = SQ_NONE;
   pendingTo = SQ_NONE;

   [self showPiecesAnimate: YES];
   [self updateMoveList];
   [self showBookMoves];

   engineIsPlaying = NO;
   [engineController abortSearch];
   [engineController sendCommand: @"ucinewgame"];
   [engineController commitCommands];
   if (gameMode == GAME_MODE_ANALYSE)
      [self engineGo];
}


- (void)gameFromFEN:(NSString *)fen {
   [game release];
   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];

   game = [[Game alloc] initWithGameController: self FEN: fen];
   if ([remoteEngineController isConnected])
      [remoteEngineController sendToServer: [game remoteEngineGameString]];
   gameLevel = [[Options sharedOptions] gameLevel];
   gameMode = [[Options sharedOptions] gameMode];
   [game setTimeControlWithTime: [[Options sharedOptions] baseTime]
                      increment: [[Options sharedOptions] timeIncrement]];
   pieceViews = [[NSMutableArray alloc] init];
   pendingFrom = SQ_NONE;
   pendingTo = SQ_NONE;

   [self showPiecesAnimate: YES];
   [moveListView setText: [game moveListString]];
   [self showBookMoves];

   engineIsPlaying = NO;
   [engineController abortSearch];
   [engineController sendCommand: @"ucinewgame"];
   [engineController commitCommands];
   if (gameMode == GAME_MODE_ANALYSE)
      [self engineGo];
}


- (void)showBookMoves {
   if ([[Options sharedOptions] showBookMoves]) {
      NSString *s = [game bookMovesAsString];
      if (s)
         [bookMovesView setText: [NSString stringWithFormat: @"  Book: %@",
                                           [game bookMovesAsString]]];
      else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
         [bookMovesView setText: @"  Book:"];
      else if ([[bookMovesView text] hasPrefix: @"  Book:"])
         [bookMovesView setText: @""];
   }
   else if ([[bookMovesView text] hasPrefix: @"  Book:"])
      [bookMovesView setText: @""];
}


- (void)changePlayStyle {
}


- (void)startThinking {
   if ([game sideToMove] == WHITE) {
      [[Options sharedOptions] setGameMode: GAME_MODE_COMPUTER_WHITE];
      [self setGameMode: GAME_MODE_COMPUTER_WHITE];
   }
   else {
      [[Options sharedOptions] setGameMode: GAME_MODE_COMPUTER_BLACK];
      [self setGameMode: GAME_MODE_COMPUTER_BLACK];
   }
}


- (BOOL)engineIsThinking {
   return [engineController engineIsThinking];
}


- (void)piecesSetUserInteractionEnabled:(BOOL)enable {
   for (PieceImageView *piv in pieceViews)
      [piv setUserInteractionEnabled: enable];
}


- (void)connectToServer {
   NSLog(@"Connecting to server %@ on port %d",
         [[Options sharedOptions] serverName], [[Options sharedOptions] serverPort]);
   [remoteEngineController
      connectToServer: [[Options sharedOptions] serverName]
                 port: [[Options sharedOptions] serverPort]];
   // [remoteEngineController sendToServer: [game remoteEngineGameString]];
   [[boardView superview] sendSubviewToBack: searchStatsView];
}

- (void)disconnectFromServer {
   NSLog(@"Disconnecting from server %@ on port %d",
         [[Options sharedOptions] serverName], [[Options sharedOptions] serverPort]);
   [remoteEngineController disconnect];
}


- (BOOL)isConnectedToServer {
   return [remoteEngineController isConnected];
}


- (void)redrawPieces {
   NSLog(@"preparing to redraw pieces");
   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];
   pieceViews = [[NSMutableArray alloc] init];
   [self showPiecesAnimate: NO];
   NSLog(@"finished redrawing pieces");
}


- (void)dealloc {
   NSLog(@"GameController dealloc");
   [remoteEngineController release];
   [engineController quit];
   [game release];
   [pieceViews release]; // Should we remove them from superview first??
   for (Piece p = WP; p <= BK; p++)
      [pieceImages[p] release];
   [engineController release];

   [[NSNotificationCenter defaultCenter] removeObserver: self];
   AudioServicesDisposeSystemSoundID(clickSound);

   //while ([engineController engineThreadIsRunning]);

   [super dealloc];
}


@end
