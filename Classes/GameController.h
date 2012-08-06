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

@class EngineController;
@class LastMoveView;
@class MoveListView;
@class PieceImageView;

@interface GameController : NSObject <UIActionSheetDelegate> {
   EngineController *engineController;
   BoardView *boardView;
   UILabel *searchStatsView;
   MoveListView *moveListView;
   Game *game;
   NSMutableArray *pieceViews;
   UIImage *pieceImages[16];
   Square pendingFrom, pendingTo; // HACK for handling promotions.
   BOOL rotated;
   SystemSoundID clickSound;
   NSTimer *timer;
   Move ponderMove;
   BOOL engineIsPlaying;
   BOOL isPondering;
   LastMoveView *lastMoveView;
}

@property (nonatomic, readonly) UILabel *searchStatsView;
@property (nonatomic, readonly) Game *game;
@property (nonatomic, readonly) BOOL rotated;

- (id)initWithBoardView:(BoardView *)bv
           moveListView:(MoveListView *)mlv
        searchStatsView:(UILabel *)ssv;
- (void)startEngine;
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
- (void)showPiecesAnimate:(BOOL)animate;
- (PieceImageView *)pieceImageViewForSquare:(Square)sq;
- (void)rotateBoard;
- (void)rotateBoard:(BOOL)rotate;
- (void)playClickSound;
- (void)displaySearchStats:(NSString *)searchStats;
- (void)doEngineMove:(Move)m;
- (void)engineGo;
- (void)engineMadeMove:(NSArray *)array;
- (BOOL)usersTurnToMove;
- (BOOL)computersTurnToMove;
- (void)engineMoveNow;
- (void)gameEndTest;
- (void)loadPieceImages;
- (void)pieceSetChanged:(NSNotification *)aNotification;
- (void)gameFromPGNString:(NSString *)pgnString;
- (void)gameFromFEN:(NSString *)fen;
- (void)changePlayStyle;
- (void)startThinking;
- (BOOL)engineIsThinking;
- (void)piecesSetUserInteractionEnabled:(BOOL)enable;
- (void)redrawPieces;

@end
