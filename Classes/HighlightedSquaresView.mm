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

#import "HighlightedSquaresView.h"
#import "Options.h"


@implementation HighlightedSquaresView

@dynamic selectedSquare;

- (id)initWithFrame:(CGRect)frame squares:(Square *)sqs {
   if (self = [super initWithFrame: frame]) {
      int i;
      for (i = 0; sqs[i] != SQ_NONE; i++)
         squares[i] = sqs[i];
      squares[i] = SQ_NONE;
      selectedSquare = SQ_NONE;
      sqSize = frame.size.width / 8;
   }
   return self;
}


/// drawRect: simply draws little ellipses in the center of each square.
/// Perhaps we should switch to something prettier later.

- (void)drawRect:(CGRect)rect {
}


- (Square)selectedSquare {
   return selectedSquare;
}


- (void)setSelectedSquare:(Square)s {
   selectedSquare = s;
   [self setNeedsDisplay];
}


- (void)dealloc {
   [super dealloc];
}


@end
