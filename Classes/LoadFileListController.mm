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
#import "GameListController.h"
#import "LoadFileListController.h"
#import "PGN.h"

@implementation LoadFileListController

@synthesize boardViewController;

- (id)initWithBoardViewController:(BoardViewController *)bvc {
   if (self = [super init]) {
      boardViewController = bvc;
      [self setTitle: @"Game files"];
      fileList =
         (NSMutableArray *)
         [[[[NSFileManager defaultManager]
              contentsOfDirectoryAtPath: PGN_DIRECTORY error: NULL]
             pathsMatchingExtensions: [NSArray arrayWithObjects: @"pgn", nil]]
            retain];
   }
   return self;
}


- (void)loadView {
   [super loadView];
   [[self navigationItem]
      setLeftBarButtonItem:[[[UIBarButtonItem alloc]
                               initWithTitle: @"Cancel"
                                       style: UIBarButtonItemStylePlain
                                      target: boardViewController
                                      action: @selector(loadMenuCancelPressed)]
                              autorelease]];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 1;
}


- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
   return [fileList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   NSInteger row = [indexPath row];

   UITableViewCell *cell =
      [[self tableView] dequeueReusableCellWithIdentifier: @"any-cell"];
   if (cell == nil) {
      cell = [[[UITableViewCell alloc] initWithFrame: CGRectZero
                                     reuseIdentifier: @"any-cell"]
                autorelease];
   }
   [[cell textLabel] setText: [fileList objectAtIndex: row]];
   [cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
   return cell;
}


- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath:
   (NSIndexPath *)newIndexPath {
   NSInteger row = [newIndexPath row];

   NSLog(@"selected row %d", row);
   GameListController *glc = [[GameListController alloc]
                                initWithLoadFileListController: self
                                                      filename: [fileList objectAtIndex: row]];
   [[self navigationController] pushViewController: glc animated: YES];
   [glc release];
   [self performSelector: @selector(deselect:) withObject: tableView
              afterDelay: 0.1f];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
// Return NO if you do not want the specified item to be editable.
return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {

if (editingStyle == UITableViewCellEditingStyleDelete) {
// Delete the row from the data source
[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
}
else if (editingStyle == UITableViewCellEditingStyleInsert) {
// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
}
}
*/


 /*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


 /*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */


- (void)deselect:(UITableView *)tableView {
   [tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow]
                            animated: YES];
}


- (void)updateTableCells {
   [fileList release];
   fileList =
      (NSMutableArray *)
      [[[[NSFileManager defaultManager]
           contentsOfDirectoryAtPath: PGN_DIRECTORY error: NULL]
          pathsMatchingExtensions: [NSArray arrayWithObjects: @"pgn", nil]]
         retain];
   [[self tableView] reloadData];
}


- (void)dealloc {
   [fileList release];
   [super dealloc];
}


@end
