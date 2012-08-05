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

#import "BoardViewController.h"
#import "EpSquareController.h"
#import "SetupBoardView.h"
#import "SetupViewController.h"


@implementation EpSquareController


- (id)initWithFen:(NSString *)aFen {
   if (self = [super init]) {
      fen = [aFen retain];
      [self setContentSizeForViewInPopover: CGSizeMake(320.0f, 418.0f)];
   }
   return self;
}


- (void)loadView {
   [super loadView];
   UIView *contentView;
   CGRect r = [[UIScreen mainScreen] applicationFrame];
   [self setTitle: @"E.p. square"];
   contentView = [[UIView alloc] initWithFrame: r];
   [self setView: contentView];
   [contentView release];
   [contentView setBackgroundColor: [UIColor whiteColor]];

   [[self navigationItem]
      setRightBarButtonItem: [[[UIBarButtonItem alloc]
                                 initWithTitle: @"Done"
                                         style: UIBarButtonItemStylePlain
                                        target: self
                                        action: @selector(donePressed)]
                                autorelease]];
   boardView = [[SetupBoardView alloc] initWithController: self
                                                      fen: fen
                                                    phase: PHASE_EDIT_EP];
   r = [boardView frame];
   r.origin = CGPointMake(0.0f, 0.0f);
   [boardView setFrame: r];
   [contentView addSubview: boardView];
   [boardView release];

   UITextView *textView =
      [[UITextView alloc] initWithFrame: CGRectMake(0.0f, 320.0f, 320.0f, 80.0f)];
   [textView setFont: [UIFont systemFontOfSize: 13.0]];
   [textView setText: @"Select a square for en passant captures from the squares highlighted above, and press \"Done\" when finished. If no en passant capture is possible, just press \"Done\" without selecting a square."];
   [textView setEditable: NO];
   [contentView addSubview: textView];
   [textView release];
}


- (void)donePressed {
   BoardViewController *bvc =
      [(SetupViewController *)
          [[[self navigationController] viewControllers] objectAtIndex: 0]
         boardViewController];

   [bvc editPositionDonePressed: [boardView fen]];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)dealloc {
   [fen release];
   [super dealloc];
}


@end
