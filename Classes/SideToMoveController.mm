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

#import "BoardViewController.h"
#import "CastleRightsController.h"
#import "EpSquareController.h"
#import "SetupBoardView.h"
#import "SetupViewController.h"
#import "SideToMoveController.h"


@implementation SideToMoveController

- (id)initWithFen:(NSString *)aFen {
   if (self = [super init]) {
      fen = [aFen retain];
      [self setContentSizeForViewInPopover: CGSizeMake(320.0f, 418.0f)];
   }
   return self;
}

- (void)loadView {
   UIView *contentView;
   CGRect r = [[UIScreen mainScreen] applicationFrame];
   [self setTitle: @"Side to move"];
   contentView = [[UIView alloc] initWithFrame: r];
   [self setView: contentView];
   [contentView setBackgroundColor: [UIColor whiteColor]];

   // [self setTitle: @"Side to move"];
   [[self navigationItem]
      setRightBarButtonItem: [[[UIBarButtonItem alloc]
                                 initWithTitle: @"Done"
                                         style: UIBarButtonItemStylePlain
                                        target: self
                                        action: @selector(donePressed)]
                                autorelease]];
   boardView = [[SetupBoardView alloc] initWithController: self
                                                      fen: fen
                                                    phase: PHASE_EDIT_STM];
   [contentView addSubview: boardView];
   [boardView release];

   // UISegmentedControl for picking side to move
   NSArray *buttonNames =
      [NSArray arrayWithObjects: @"White to move", @"Black to move", nil];
   segmentedControl =
      [[UISegmentedControl alloc] initWithItems: buttonNames];
   [segmentedControl setFrame: CGRectMake(20.0f, 345.0f, 280.0f, 50.0f)];
   if ([boardView whiteIsInCheck]) {
      [segmentedControl setSelectedSegmentIndex: 0];
      [segmentedControl setEnabled: NO forSegmentAtIndex: 1];
   }
   else if ([boardView blackIsInCheck]) {
      [segmentedControl setSelectedSegmentIndex: 1];
      [segmentedControl setEnabled: NO forSegmentAtIndex: 0];
   }
   else [segmentedControl setSelectedSegmentIndex: -1];
   [segmentedControl setSegmentedControlStyle: UISegmentedControlStylePlain];
   [contentView addSubview: segmentedControl];
   [segmentedControl release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)donePressed {
   NSLog(@"Done");
   if ([segmentedControl selectedSegmentIndex] == -1)
      [[[[UIAlertView alloc] initWithTitle: @"Please select side to move!"
                                   message: @""
                                  delegate: self
                         cancelButtonTitle: nil
                         otherButtonTitles: @"OK", nil] autorelease]
         show];
   else {
      if ([[boardView maybeCastleString] isEqualToString: @"-"]) {
         Square sqs[8];
         int i;
         i = [boardView epCandidateSquaresForColor:
                           (Color)[segmentedControl selectedSegmentIndex]
                                           toArray: sqs];
         if (i == 0) {
            BoardViewController *bvc =
               [(SetupViewController *)
                   [[[self navigationController] viewControllers] objectAtIndex: 0]
                  boardViewController];
            [bvc editPositionDonePressed:
                    [NSString stringWithFormat: @"%@%c %@ -",
                              [boardView boardString],
                              (([segmentedControl selectedSegmentIndex] == 0)?
                               'w' : 'b'),
                              [boardView maybeCastleString]]];
         }
         else {
            EpSquareController *epc =
               [[EpSquareController alloc]
                  initWithFen: [NSString stringWithFormat: @"%@%c %@ -",
                                         [boardView boardString],
                                         (([segmentedControl selectedSegmentIndex] == 0)? 'w' : 'b'),
                                         [boardView maybeCastleString]]];
            [[self navigationController] pushViewController: epc animated: YES];
            [epc release];
         }
      }
      else {
         CastleRightsController *crc =
            [[CastleRightsController alloc]
               initWithFen: [NSString stringWithFormat: @"%@%c %@ -",
                                      [boardView boardString],
                                      (([segmentedControl selectedSegmentIndex] == 0)? 'w' : 'b'),
                                      [boardView maybeCastleString]]];
         [[self navigationController] pushViewController: crc animated: YES];
         [crc release];
      }
   }
}


- (void)dealloc {
   [fen release];
   [super dealloc];
}


@end
