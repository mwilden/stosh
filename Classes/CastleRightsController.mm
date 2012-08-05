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
#import "CastleRightsController.h"
#import "EpSquareController.h"
#import "SetupBoardView.h"
#import "SetupViewController.h"

@implementation CastleRightsController

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
   [self setTitle: @"Castle rights"];
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
                                                    phase: PHASE_EDIT_CASTLES];
   r = [boardView frame];
   r.origin = CGPointMake(0.0f, 48.0f);
   [boardView setFrame: r];
   [contentView addSubview: boardView];
   [boardView release];

   UILabel *label;
   UISwitch *s;
   const char *c = [[boardView maybeCastleString] UTF8String];

   label =
      [[UILabel alloc] initWithFrame: CGRectMake(21.0f, 0.0f, 120.0f, 20.0f)];
   [label setText: @"Black O-O-O"];
   [contentView addSubview: label];
   [label release];

   s = [[UISwitch alloc] initWithFrame: CGRectMake(0.0f,0.0f,0.0f,0.0f)];
   r = [s frame];
   r.origin = CGPointMake(22.0f, 20.0f);
   [s setFrame: r];
   if (strchr(c, 'q'))
      [s setOn: YES];
   else {
      [s setOn: NO];
      [s setEnabled: NO];
   }
   [contentView addSubview: s];
   bOOOswitch = s;
   [s release];

   label =
      [[UILabel alloc] initWithFrame: CGRectMake(21.0f, 368.0f, 120.0f, 20.0f)];
   [label setText: @"White O-O-O"];
   [contentView addSubview: label];
   [label release];

   s = [[UISwitch alloc] initWithFrame: CGRectMake(0.0f,0.0f,0.0f,0.0f)];
   r = [s frame];
   r.origin = CGPointMake(22.0f, 388.0f);
   [s setFrame: r];
   if (strchr(c, 'Q'))
      [s setOn: YES];
   else {
      [s setOn: NO];
      [s setEnabled: NO];
   }
   [contentView addSubview: s];
   wOOOswitch = s;
   [s release];

   label =
      [[UILabel alloc] initWithFrame: CGRectMake(211.0f, 0.0f, 120.0f, 20.0f)];
   [label setText: @"Black O-O"];
   [contentView addSubview: label];
   [label release];

   s = [[UISwitch alloc] initWithFrame: CGRectMake(0.0f,0.0f,0.0f,0.0f)];
   r = [s frame];
   r.origin = CGPointMake(203.0f, 20.0f);
   [s setFrame: r];
   if (strchr(c, 'k'))
      [s setOn: YES];
   else {
      [s setOn: NO];
      [s setEnabled: NO];
   }
   [contentView addSubview: s];
   bOOswitch = s;
   [s release];

   label =
      [[UILabel alloc] initWithFrame: CGRectMake(211.0f, 368.0f, 120.0f, 20.0f)];
   [label setText: @"White O-O"];
   [contentView addSubview: label];
   [label release];

   s = [[UISwitch alloc] initWithFrame: CGRectMake(0.0f,0.0f,0.0f,0.0f)];
   r = [s frame];
   r.origin = CGPointMake(203.0f, 388.0f);
   [s setFrame: r];
   if (strchr(c, 'K'))
      [s setOn: YES];
   else {
      [s setOn: NO];
      [s setEnabled: NO];
   }
   [contentView addSubview: s];
   wOOswitch = s;
   [s release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)donePressed {
   NSArray *substrs =
      [fen componentsSeparatedByCharactersInSet:
              [NSCharacterSet whitespaceCharacterSet]];
   char cstr[8];
   int i = 0;
   if ([wOOswitch isOn]||[wOOOswitch isOn]||[bOOswitch isOn]||[bOOOswitch isOn]){
      if ([wOOswitch isOn]) cstr[i++] = 'K';
      if ([wOOOswitch isOn]) cstr[i++] = 'Q';
      if ([bOOswitch isOn]) cstr[i++] = 'k';
      if ([bOOOswitch isOn]) cstr[i++] = 'q';
   }
   else cstr[i++] = '-';
   cstr[i] = '\0';

   Square epSqs[8];
   if ([boardView epCandidateSquares: epSqs]) {
      EpSquareController *epc =
         [[EpSquareController alloc]
            initWithFen: [NSString stringWithFormat: @"%@ %@ %s -",
                             [substrs objectAtIndex: 0],
                             [substrs objectAtIndex: 1],
                                   cstr]];
      [[self navigationController] pushViewController: epc animated: YES];
      [epc release];
   }
   else {
      BoardViewController *bvc =
         [(SetupViewController *)
             [[[self navigationController] viewControllers] objectAtIndex: 0]
            boardViewController];

      [bvc editPositionDonePressed:
              [NSString stringWithFormat: @"%@ %@ %s -",
                  [substrs objectAtIndex: 0], [substrs objectAtIndex: 1],
                        cstr]];
   }
}


- (void)dealloc {
   [fen release];
   [super dealloc];
}


@end
