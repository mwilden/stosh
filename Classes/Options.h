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

#import <UIKit/UIKit.h>

@interface Options : NSObject {
   UIColor *darkSquareColor, *lightSquareColor, *highlightColor;
   UIImage *darkSquareImage, *lightSquareImage;
}

@property (nonatomic, readonly) UIColor *darkSquareColor;
@property (nonatomic, readonly) UIColor *lightSquareColor;
@property (nonatomic, readonly) UIColor *highlightColor;
@property (nonatomic, readonly) UIImage *darkSquareImage;
@property (nonatomic, readonly) UIImage *lightSquareImage;

+ (Options *)sharedOptions;

- (void)updateColors;

@end
