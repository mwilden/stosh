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
#import "RemoteEngineTableController.h"
#import "RemoteEngineTextFieldController.h"

@implementation RemoteEngineTextFieldController

- (id)initWithRemoteEngineTableController:(RemoteEngineTableController *)r
                                fieldName:(NSString *)fname {
   if (self = [super init]) {
      retc = r;
      fieldName = [fname retain];

      [[NSNotificationCenter defaultCenter]
         addObserver: self
            selector: @selector(editingEnded:)
                name: @"UITextFieldTextDidEndEditingNotification"
              object: nil];
   }
   return self;
}


- (void)loadView {
   [super loadView];
   [[self navigationItem] setTitle: fieldName];

   UIView *contentView =
      [[UIView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]];
   [contentView setBackgroundColor: [UIColor lightGrayColor]];
   [self setView: contentView];
   [contentView release];

   textField = [[UITextField alloc]
                  initWithFrame: CGRectMake(20.0f, 20.0f, 280.0f, 28.0f)];
   [textField setDelegate: self];
   [textField setBorderStyle: UITextBorderStyleBezel];

   if ([fieldName isEqualToString: @"Server IP address"]) {
      [textField setText: [[Options sharedOptions] serverName]];
      [textField setAutocapitalizationType: UITextAutocapitalizationTypeNone];
      [textField setAutocorrectionType: UITextAutocorrectionTypeNo];
      [textField setKeyboardType: UIKeyboardTypeASCIICapable];
   }
   else if ([fieldName isEqualToString: @"Server port"]) {
      [textField setText:
                    [NSString stringWithFormat: @"%d",
                              [[Options sharedOptions] serverPort]]];
      [textField setKeyboardType: UIKeyboardTypeNumberPad];
   }
   else
      assert(NO);

   [textField setClearButtonMode: UITextFieldViewModeAlways];
   [textField setAutocapitalizationType: UITextAutocapitalizationTypeNone];
   [textField setAutocorrectionType: UITextAutocorrectionTypeNo];
   [textField setBackgroundColor: [UIColor whiteColor]];
   [contentView addSubview: textField];
   [textField release];
}


- (void)editingEnded:(NSNotification *)aNotification {
   if ([fieldName isEqualToString: @"Server IP address"])
      [[Options sharedOptions] setServerName: [textField text]];
   else if ([fieldName isEqualToString: @"Server port"]) {
      int port;
      [[NSScanner scannerWithString: [textField text]] scanInteger: &port];
      [[Options sharedOptions] setServerPort: port];
   }
   else
      assert(NO);
   [retc updateTableCells];
}


- (BOOL)textFieldShouldReturn:(UITextField *)tf {
   [self editingEnded: nil];
   [[self navigationController] popViewControllerAnimated: YES];
   return NO;
}


- (void)dealloc {
   [[NSNotificationCenter defaultCenter] removeObserver: self];
   [fieldName release];
   [super dealloc];
}


@end
