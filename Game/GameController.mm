#import "GameController.h"
#import "MoveListView.h"
#import "PieceImageView.h"
#import "PGN.h"
#import "Game.h"
#import "BoardView.h"
#import "ChessMove.h"

#include "misc.h"

using namespace Chess;

@implementation GameController

@synthesize game, rotated;

- (id)initWithBoardView:(BoardView *)bv
           moveListView:(MoveListView *)mlv {
   if (self = [super init]) {
      boardView = bv;
      moveListView = mlv;

      game = [[Game alloc] initWithGameController: self];
      pieceViews = [[NSMutableArray alloc] init];
      pendingFrom = SQ_NONE;
      pendingTo = SQ_NONE;
      rotated = NO;
   }
   return self;
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

   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];

   game = [[Game alloc] initWithGameController: self];

    [game setWhitePlayer: @"White"];
    [game setBlackPlayer: @"Black"];

   pieceViews = [[NSMutableArray alloc] init];
   pendingFrom = SQ_NONE;
   pendingTo = SQ_NONE;

   [moveListView setText: @""];
   [self showPieces];
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

      [self updateMoveList];
      [self gameEndTest];
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
      [menu release];
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
   [game doMoveFrom: fSq to: tSq promotion: prom];
   [self updateMoveList];
   pendingFrom = pendingTo = SQ_NONE;

   [self gameEndTest];
}


- (void)promotionMenu {
    UIActionSheet* sheet = [[UIActionSheet alloc]
      initWithTitle: @"Promote to:"
      delegate: self
      cancelButtonTitle: nil
      destructiveButtonTitle: nil
      otherButtonTitles: @"Queen", @"Rook", @"Knight", @"Bishop", nil];
    [sheet showInView: [boardView superview]];
    [sheet release];
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

   [self updateMoveList];
   [self gameEndTest];
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

   float squareSize = [boardView squareSize];
   CGRect rect = CGRectMake(0.0f, 0.0f, squareSize, squareSize);
   rect.origin = CGPointMake((int(sq)%8) * squareSize, (7-int(sq)/8) * squareSize);
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

      // Update the game:
      [game takeBack];
   }
   [self updateMoveList];
}


- (void)takeBackAllMoves {
   if (![game atBeginning]) {

      [boardView hideLastMove];

      // Release piece images
      for (PieceImageView *piv in pieceViews)
         [piv removeFromSuperview];
      [pieceViews release];

      // Update game
      [game toBeginning];

      // Update board
      pieceViews = [[NSMutableArray alloc] init];
      [self showPieces];

      [self updateMoveList];
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
   }
   [self updateMoveList];
}


- (void)replayAllMoves {
   if (![game atEnd]) {

      [boardView hideLastMove];

      // Release piece images
      for (PieceImageView *piv in pieceViews)
         [piv removeFromSuperview];
      [pieceViews release];

      // Update game
      [game toEnd];

      // Update board
      pieceViews = [[NSMutableArray alloc] init];
      [self showPieces];

      [self updateMoveList];
   }
}


/// showPiecesAnimate: creates the piece image views and attaches them as
/// subviews to the board view.

- (void)showPieces {
   float squareSize = [boardView squareSize];
   CGRect rect = CGRectMake(0.0f, 0.0f, squareSize, squareSize);
   for (Square sq = SQ_A1; sq <= SQ_H8; sq++) {
      Square s = [self rotateSquare: sq];
      Piece p = [self pieceOn: s];
      if (p != EMPTY) {
         assert(piece_is_ok(p));
         rect.origin = CGPointMake((int(s)%8) * squareSize, (7-int(s)/8) * squareSize);
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
}


- (void)rotateBoard:(BOOL)rotate {
   if (rotate != rotated)
      [self rotateBoard];
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
   NSString *pieceSet = @"USCF";
   for (Piece p = WP; p <= BK; p++) {
      if (piece_is_ok(p)) {
        pieceImages[p] =
           [[UIImage imageNamed: [NSString stringWithFormat: @"%@%@96.tiff",
                                           pieceSet, pieceImageNames[p]]]
              retain];
      }
      else
         pieceImages[p] = nil;
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

   pieceViews = [[NSMutableArray alloc] init];
   pendingFrom = SQ_NONE;
   pendingTo = SQ_NONE;

   [self showPieces];
   [self updateMoveList];
}


- (void)gameFromFEN:(NSString *)fen {
   [game release];
   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];

   game = [[Game alloc] initWithGameController: self FEN: fen];
   pieceViews = [[NSMutableArray alloc] init];
   pendingFrom = SQ_NONE;
   pendingTo = SQ_NONE;

   [self showPieces];
   [moveListView setText: [game moveListString]];
}


- (void)piecesSetUserInteractionEnabled:(BOOL)enable {
   for (PieceImageView *piv in pieceViews)
      [piv setUserInteractionEnabled: enable];
}


- (void)redrawPieces {
   NSLog(@"preparing to redraw pieces");
   for (PieceImageView *piv in pieceViews)
      [piv removeFromSuperview];
   [pieceViews release];
   pieceViews = [[NSMutableArray alloc] init];
   [self showPieces];
   NSLog(@"finished redrawing pieces");
}


- (void)dealloc {
   NSLog(@"GameController dealloc");
   [game release];
   [pieceViews release];
   for (Piece p = WP; p <= BK; p++)
      [pieceImages[p] release];

   [[NSNotificationCenter defaultCenter] removeObserver: self];

   [super dealloc];
}


@end
