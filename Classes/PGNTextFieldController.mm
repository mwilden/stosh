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

#import "Game.h"
#import "GameDetailsTableController.h"
#import "PGNTextFieldController.h"


@implementation PGNTextFieldController


- (id)initWithGameDetailsController:(GameDetailsTableController *)gdtc
                             pgnTag:(NSString *)tag {
   if (self = [super init]) {
      gameDetailsController = gdtc;
      pgnTag = tag;

      [[NSNotificationCenter defaultCenter]
         addObserver: self
            selector: @selector(editingEnded:)
                name: @"UITextFieldTextDidEndEditingNotification"
              object: nil];
      [self setContentSizeForViewInPopover: [gdtc contentSizeForViewInPopover]];
   }
   return self;
}


- (void)loadView {
   [super loadView];
   if ([pgnTag isEqualToString: @"whitePlayer"])
      [[self navigationItem] setTitle: @"White"];
   else if ([pgnTag isEqualToString: @"blackPlayer"])
      [[self navigationItem] setTitle: @"Black"];
   else if ([pgnTag isEqualToString: @"event"])
      [[self navigationItem] setTitle: @"Event"];
   else if ([pgnTag isEqualToString: @"site"])
      [[self navigationItem] setTitle: @"Site"];
   else if ([pgnTag isEqualToString: @"round"])
      [[self navigationItem] setTitle: @"Round"];

   UIView *contentView =
      [[UIView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]];
   [contentView setBackgroundColor: [UIColor lightGrayColor]];
   [self setView: contentView];
   [contentView release];

   textField = [[UITextField alloc]
                  initWithFrame: CGRectMake(20.0f, 20.0f, 280.0f, 28.0f)];
   [textField setDelegate: self];
   [textField setBorderStyle: UITextBorderStyleBezel];
   [textField setText: [[gameDetailsController game] valueForKey: pgnTag]];
   [textField setClearButtonMode: UITextFieldViewModeAlways];
   [textField setBackgroundColor: [UIColor whiteColor]];
   [contentView addSubview: textField];
   [textField release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)editingEnded:(NSNotification *)aNotification {
   [[gameDetailsController game] setValue: [textField text] forKey: pgnTag];
   [gameDetailsController updateTableCells];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
   [self editingEnded: nil];
   [[self navigationController] popViewControllerAnimated: YES];
   return NO;
}


- (void)dealloc {
   [[NSNotificationCenter defaultCenter] removeObserver: self];
   [super dealloc];
}


@end
