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

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioServices.h>

#import "BoardView.h"
#import "Game.h"
#import "Options.h"

@class LastMoveView;
@class MoveListView;
@class PieceImageView;

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
