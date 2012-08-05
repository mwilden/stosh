/*
  Stockfish, a chess program for the Apple iPhone.
  Copyright (C) 2004-2010 Tord Romstad, Marco Costalba, Joona Kiiski

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

#import "SelectedSquareView.h"


@implementation SelectedSquareView


- (id)initWithFrame:(CGRect)frame {
   if (self = [super initWithFrame:frame]) {
      hidden = YES;
      size = frame.size.width;
   }
   return self;
}


- (void)drawRect:(CGRect)rect {
   if (!hidden) {
      [[UIColor blackColor] set];
      UIRectFrame(CGRectMake(1.0f, 1.0f, size-1, size-1));
      UIRectFrame(CGRectMake(2.0f, 2.0f, size-3, size-3));
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
         UIRectFrame(CGRectMake(3.0f, 3.0f, size-5, size-5));
         UIRectFrame(CGRectMake(4.0f, 4.0f, size-7, size-7));
      }
   }
}


- (void)hide {
   hidden = YES;
   [self setNeedsDisplay];
   [super setNeedsDisplay];
}


- (void)moveToPoint:(CGPoint)point {
   CGRect r = [self frame];
   r.origin = point;
   hidden = NO;
   [self setFrame: r];
   [self setNeedsDisplay];
}


- (void)dealloc {
   [super dealloc];
}


@end
