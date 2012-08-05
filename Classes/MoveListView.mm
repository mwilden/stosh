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

#import "GameController.h"
#import "MoveListView.h"


@implementation MoveListView

@synthesize gameController;

- (id)initWithFrame:(CGRect)frame {
   if (self = [super initWithFrame: frame]) {
      [self setScrollEnabled: NO];
   }
   return self;
}


- (void)drawRect:(CGRect)rect {
   // Drawing code
}


/// Touch gestures in the move list view: Swiping the finger to the left or
/// right is used to take back or replay moves.

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
   touchStartPoint = [[touches anyObject] locationInView: self];
   horizontalSwipe = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
   if (horizontalSwipe) {
      CGPoint pt = [[touches anyObject] locationInView: self];
      if (abs(pt.x - touchStartPoint.x) < 12.0
          && abs(pt.y - touchStartPoint.y) > 10.0f) {
         NSLog(@"no longer horizontal swipe");
         horizontalSwipe = NO;
      }
   }
   else
      // Hand over the touch event to superclass, to support scrolling.
      [super touchesMoved: touches withEvent: event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
   NSLog(@"touches ended");
   if (horizontalSwipe) {
      CGPoint pt = [[touches anyObject] locationInView: self];
      if (pt.x - touchStartPoint.x > 12.0f)
         [gameController replayMove];
      else if (pt.x - touchStartPoint.x < -12.0)
         [gameController takeBackMove];
   }
}


/// Override UITextView's setText: method by converting hyphens to non-breaking
/// hyphens, to prevent notation of castling moves to be split between two
/// lines. Also replaces piece characters with figurines if this option is
/// switched on.

- (void)setText:(NSString *)string {
   unichar c = 0x2011;
   NSString *s = [NSString stringWithCharacters: &c length: 1];

   string = [string stringByReplacingOccurrencesOfString: @"-"
                                              withString: s];

   if ([[Options sharedOptions] figurineNotation]) {
      NSString *pc[6] = { @"K", @"Q", @"R", @"B", @"N" };
      int i;
      for (i = 0, c = 0x2654; i < 5; i++, c++) {
         s = [NSString stringWithCharacters: &c length: 1];
         string = [string stringByReplacingOccurrencesOfString: pc[i]
                                                    withString: s];
      }
   }
   [super setText: string];
}


/// Clean up.

- (void)dealloc {
   [super dealloc];
}


@end
