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

#import "GameListController.h"
#import "GamePreview.h"
#import "LoadFileListController.h"
#import "PGN.h"
#import "PGN.h"

@implementation GameListController

- (id)initWithLoadFileListController:(LoadFileListController *)lflc
                            filename:(NSString *)aFilename {
   if (self = [super init]) {
      loadFileListController = lflc;
      filename = aFilename;
      pgnFile = [[PGN alloc] initWithFilename: filename];
      [pgnFile initializeGameIndices];
   }
   return self;
}


- (void)loadView {
   [super loadView];

   [[self navigationItem]
      setTitle: [filename stringByReplacingOccurrencesOfString: @".pgn"
                                                    withString: @""]];

   UIBarButtonItem *button =
      [[UIBarButtonItem alloc]
         initWithBarButtonSystemItem: UIBarButtonSystemItemTrash
                              target: self
                              action: @selector(deleteFile:)];
   [[self navigationItem] setRightBarButtonItem: button];
   [button release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
   return [pgnFile numberOfGames];
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   NSInteger row = [indexPath row];
   UITableViewCell *cell =
      [[self tableView] dequeueReusableCellWithIdentifier: @"any-cell"];
   if (cell == nil)
      cell = [[[UITableViewCell alloc] initWithFrame: CGRectZero
                                     reuseIdentifier: @"any-cell"]
                autorelease];
   [pgnFile goToGameNumber: row];
   [[cell textLabel] setText:
                        [NSString stringWithFormat: @"%@-%@ %@",
                                  [pgnFile white], [pgnFile black], [pgnFile result]]];
   [cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
   return cell;
}


- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath:
   (NSIndexPath *)newIndexPath {
   NSInteger row = [newIndexPath row];

   GamePreview *gp = [[GamePreview alloc] initWithPGN: pgnFile gameNumber: row];
   [[self navigationController] pushViewController: gp animated: YES];
   [gp release];
   [self performSelector: @selector(deselect:) withObject: tableView
              afterDelay: 0.1f];
}


- (void)deselect:(UITableView *)tableView {
   [tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow]
                            animated: YES];
}


- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
   if (buttonIndex == 1) {
      remove([[PGN_DIRECTORY stringByAppendingPathComponent: filename]
                UTF8String]);
      [loadFileListController updateTableCells];
      [[self navigationController] popViewControllerAnimated: YES];
   }
}


- (void)deleteFile:(id)sender {
   [[[[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:
                                                      @"Delete file %@?",
                                                   filename]
                                message: nil
                               delegate: self
                      cancelButtonTitle: @"Cancel"
                      otherButtonTitles: @"OK", nil] autorelease]
      show];
}


- (void)dealloc {
   [pgnFile release];
   [super dealloc];
}


@end
