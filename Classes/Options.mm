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

#import "Options.h"


@implementation Options

@synthesize darkSquareColor, lightSquareColor, highlightColor;
@synthesize darkSquareImage, lightSquareImage;

- (id)init {
   if (self = [super init]) {
      darkSquareColor = lightSquareColor = highlightColor = nil;
      [self updateColors];
   }
   return self;
}


- (void)updateColors {
   [darkSquareColor release];
   [lightSquareColor release];
   [highlightColor release];
   [darkSquareImage release]; darkSquareImage = nil;
   [lightSquareImage release]; lightSquareImage = nil;
  darkSquareColor = [[UIColor colorWithRed: 0.20 green: 0.40 blue: 0.70
                                     alpha: 1.0]
                       retain];
  lightSquareColor = [[UIColor colorWithRed: 0.69 green: 0.78 blue: 1.0
                                      alpha: 1.0]
                        retain];
  highlightColor = [[UIColor purpleColor] retain];
}

- (void)dealloc {
   [darkSquareImage release];
   [lightSquareImage release];
   [super dealloc];
}


+ (Options *)sharedOptions {
   static Options *o = nil;
   if (o == nil) {
      o = [[Options alloc] init];
   }
   return o;
}

@end
