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
@dynamic colorScheme, pieceSet;

- (id)init {
   if (self = [super init]) {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

      pieceSet = [defaults objectForKey: @"pieceSet3"];
      if (!pieceSet) {
         // For some reason, I prefer the Leipzig pieces on the iPhone,
         // but Alpha on the iPad.
         pieceSet = [@"Alpha" retain];
         [defaults setObject: @"Alpha" forKey: @"pieceSet3"];
      }

      colorScheme = [defaults objectForKey: @"colorScheme3"];
      if (!colorScheme) {
         colorScheme = [@"Green" retain];
         [defaults setObject: @"Green" forKey: @"colorScheme3"];
      }
      darkSquareColor = lightSquareColor = highlightColor = nil;
      [self updateColors];

      [defaults synchronize];
   }
   return self;
}


- (void)updateColors {
   [darkSquareColor release];
   [lightSquareColor release];
   [highlightColor release];
   [darkSquareImage release]; darkSquareImage = nil;
   [lightSquareImage release]; lightSquareImage = nil;
   if ([colorScheme isEqualToString: @"Blue"]) {
      darkSquareColor = [[UIColor colorWithRed: 0.20 green: 0.40 blue: 0.70
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 0.69 green: 0.78 blue: 1.0
                                          alpha: 1.0]
                            retain];
      highlightColor = [[UIColor purpleColor] retain];
   }
   else if ([colorScheme isEqualToString: @"Gray"]) {
      darkSquareColor = [[UIColor colorWithRed: 0.5 green: 0.5 blue: 0.5
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 0.8 green: 0.8 blue: 0.8
                                          alpha: 1.0]
                            retain];
      highlightColor = [[UIColor blueColor] retain];
   }
   else if ([colorScheme isEqualToString: @"Green"]) {
      darkSquareColor = [[UIColor colorWithRed: 0.57 green: 0.40 blue: 0.35
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 0.9 green: 0.8 blue: 0.7
                                          alpha: 1.0]
                            retain];
      darkSquareImage = [[UIImage imageNamed: @"DarkGreenMarble96.tiff"] retain];
      lightSquareImage = [[UIImage imageNamed: @"LightGreenMarble96.tiff"] retain];
      highlightColor = [[UIColor blueColor] retain];
   }
   else if ([colorScheme isEqualToString: @"Red"]) {
      darkSquareColor = [[UIColor colorWithRed: 0.6 green: 0.28 blue: 0.28
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 1.0 green: 0.8 blue: 0.8
                                          alpha: 1.0]
                            retain];
      highlightColor = [[UIColor blueColor] retain];
   }
   else if ([colorScheme isEqualToString: @"Wood"]) {
      darkSquareColor = [[UIColor colorWithRed: 0.57 green: 0.40 blue: 0.35
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 0.9 green: 0.8 blue: 0.7
                                          alpha: 1.0]
                            retain];
      darkSquareImage = [[UIImage imageNamed: @"DarkWood96.tiff"] retain];
      lightSquareImage = [[UIImage imageNamed: @"LightWood96.tiff"] retain];
      highlightColor = [[UIColor blueColor] retain];
   }
   else if ([colorScheme isEqualToString: @"Marble"]) {
      darkSquareColor = [[UIColor colorWithRed: 0.57 green: 0.40 blue: 0.35
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 0.9 green: 0.8 blue: 0.7
                                          alpha: 1.0]
                            retain];
      darkSquareImage = [[UIImage imageNamed: @"DarkMarble96.tiff"] retain];
      lightSquareImage = [[UIImage imageNamed: @"LightMarble96.tiff"] retain];
      highlightColor = [[UIColor blueColor] retain];
   }
   else { // Default brown color scheme
      darkSquareColor = [[UIColor colorWithRed: 0.57 green: 0.40 blue: 0.35
                                         alpha: 1.0]
                           retain];
      lightSquareColor = [[UIColor colorWithRed: 0.9 green: 0.8 blue: 0.7
                                          alpha: 1.0]
                            retain];
      highlightColor = [[UIColor blueColor] retain];
   }
   // Post a notification about the new colors, in order to make the board
   // update itself:
   [[NSNotificationCenter defaultCenter]
      postNotificationName: @"StockfishColorSchemeChanged"
                    object: self];
}


- (NSString *)colorScheme {
   return colorScheme;
}


- (void)setColorScheme:(NSString *)newColorScheme {
   [colorScheme release];
   colorScheme = [newColorScheme retain];
   [[NSUserDefaults standardUserDefaults] setObject: newColorScheme
                                             forKey: @"colorScheme3"];
   [[NSUserDefaults standardUserDefaults] synchronize];
   [[NSNotificationCenter defaultCenter]
      postNotificationName: @"StockfishPieceSetChanged"
                    object: self];
   [self updateColors];
}


- (NSString *)pieceSet {
   return pieceSet;
}


- (void)setPieceSet:(NSString *)newPieceSet {
   [pieceSet release];
   pieceSet = [newPieceSet retain];
   [[NSUserDefaults standardUserDefaults] setObject: newPieceSet
                                             forKey: @"pieceSet3"];
   [[NSUserDefaults standardUserDefaults] synchronize];
   [[NSNotificationCenter defaultCenter]
      postNotificationName: @"StockfishPieceSetChanged"
                    object: self];
}


- (void)dealloc {
   [darkSquareImage release];
   [lightSquareImage release];
   [colorScheme release];
   [pieceSet release];
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
