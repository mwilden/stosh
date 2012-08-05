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
#import "GamePreview.h"
#import "LoadFileListController.h"
#import "PGN.h"
//#import "TextChoiceCell.h"


@implementation GamePreview

- (id)initWithPGN:(PGN *)pgn gameNumber:(int)aNumber {
   if (self = [super initWithStyle: UITableViewStyleGrouped]) {
      pgnFile = pgn;
      gameNumber = aNumber;
      [pgnFile goToGameNumber: gameNumber];
   }
   return self;
}


- (void)loadView {
   [super loadView];
   [[self navigationItem] setRightBarButtonItem:
                             [[[UIBarButtonItem alloc]
                                 initWithTitle: @"Load game"
                                         style: UIBarButtonItemStylePlain
                                        target: self
                                        action: @selector(loadButtonPressed)]
                                autorelease]];
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
   return 7;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   NSInteger row = [indexPath row];
   NSInteger section = [indexPath section];
   /*
     TextChoiceCell *cell =
     (TextChoiceCell *)[tableView dequeueReusableCellWithIdentifier:
     @"any-cell"];
     if (cell == nil) {
     cell = [[[TextChoiceCell alloc] initWithFrame: CGRectZero
     reuseIdentifier: @"any-cell"
     nameLabelWidth: 120.0f]
     autorelease];
     [cell setRightMargin: 10.0f];
     }
   */

   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"any-cell"];
   if (cell == nil)
      cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1
                                     reuseIdentifier: @"any-cell"]
                autorelease];

   if (section == 0) {
      if(row == 0) {
         [[cell textLabel] setText: @"White"];
         [[cell detailTextLabel] setText: [pgnFile white]];
         //[cell setValueText: [pgnFile white]];
      }
      else if(row == 1) {
         [[cell textLabel] setText: @"Black"];
         [[cell detailTextLabel] setText: [pgnFile black]];
         //[cell setValueText: [pgnFile black]];
      }
      else if(row == 2) {
         [[cell textLabel] setText: @"Event"];
         [[cell detailTextLabel] setText: [pgnFile event]];
         //[cell setValueText: [pgnFile event]];
      }
      else if(row == 3) {
         [[cell textLabel] setText: @"Site"];
         [[cell detailTextLabel] setText: [pgnFile site]];
         //[cell setValueText: [pgnFile site]];
      }
      else if(row == 4) {
         [[cell textLabel] setText: @"Date"];
         [[cell detailTextLabel] setText: [pgnFile date]];
         //[cell setValueText: [pgnFile date]];
      }
      else if(row == 5) {
         [[cell textLabel] setText: @"Round"];
         [[cell detailTextLabel] setText: [pgnFile round]];
         //[cell setValueText: [pgnFile round]];
      }
      else if(row == 6) {
         [[cell textLabel] setText: @"Result"];
         [[cell detailTextLabel] setText: [pgnFile result]];
         //[cell setValueText: [pgnFile result]];
      }
   }
   return cell;
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
   [tableView deselectRowAtIndexPath: indexPath animated: NO];
   // Navigation logic may go here. Create and push another view controller.
   // AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
   // [self.navigationController pushViewController:anotherViewController];
   // [anotherViewController release];
}


- (void)loadButtonPressed {
   NSLog(@"Load button pressed");

   // HACK: This is ugly.  :-(
   [[(LoadFileListController *) [[[self navigationController] viewControllers]
                                   objectAtIndex: 0]
                                boardViewController]
      loadMenuDonePressedWithGame: [pgnFile pgnStringForGameNumber: gameNumber]];
}


- (void)dealloc {
   [super dealloc];
}


@end
