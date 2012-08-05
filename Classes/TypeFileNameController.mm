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

#import "SaveFileListController.h"
#import "TypeFileNameController.h"


@implementation TypeFileNameController

- (id)initWithSaveFileListController:(SaveFileListController *)sflc {
   if (self = [super init]) {
      saveFileListController = sflc;
      UIBarButtonItem *button = [[[UIBarButtonItem alloc]
                                    initWithTitle: @"Done"
                                            style: UIBarButtonItemStylePlain
                                           target: self
                                           action: @selector(doneButtonPressed:)]
                                   autorelease];
      [[self navigationItem] setRightBarButtonItem: button];
      [self setContentSizeForViewInPopover: [sflc contentSizeForViewInPopover]];
   }
   return self;
}


- (void)loadView {
   [[self navigationItem] setTitle: @"New file"];
   UIView *contentView =
      [[UIView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]];
   [contentView setBackgroundColor: [UIColor lightGrayColor]];
   [self setView: contentView];
   [contentView release];

   UILabel *label;

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      label = [[UILabel alloc] initWithFrame: CGRectMake(10.0f, 20.0f, 90.0f, 28.0f)];
   else
      label = [[UILabel alloc] initWithFrame: CGRectMake(10.0f, 20.0f, 80.0f, 28.0f)];
   [label setText: @"File name:"];
   [label setBackgroundColor: [UIColor lightGrayColor]];
   [contentView addSubview: label];
   [label release];

   textField = [[UITextField alloc] initWithFrame: CGRectMake(100.0f, 20.0f, 210.0f, 28.0f)];
   [textField setDelegate: self];
   [textField setBorderStyle: UITextBorderStyleBezel];
   [textField setBackgroundColor: [UIColor whiteColor]];
   [textField setText: @""];
   [contentView addSubview: textField];
   [textField release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)doneButtonPressed:(id)sender {
   [saveFileListController addFileName: [textField text]];
   [[self navigationController] popViewControllerAnimated: YES];
}


- (BOOL)textFieldShouldReturn:(UITextField *)tField {
   [saveFileListController addFileName: [textField text]];
   [[self navigationController] popViewControllerAnimated: YES];
   return NO;
}


- (void)dealloc {
   [super dealloc];
}


@end
