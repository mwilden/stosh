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

#import "PlayStyleViewController.h"


@implementation PlayStyleViewController


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 1;
}


- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
   return 3;
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

   if (row == 0) {
      [[cell textLabel] setText: @"Solid"];
   }
   else if (row == 1) {
      [[cell textLabel] setText: @"Active"];
   }
   else if (row == 2) {
      [[cell textLabel] setText: @"Aggressive"];
   }
   return cell;
}


- (void)deselect {
   [[self tableView] deselectRowAtIndexPath:
                        [[self tableView] indexPathForSelectedRow]
                                   animated: YES];
}

- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath:
   (NSIndexPath *)newIndexPath {
   int row = [newIndexPath row];
   int section = [newIndexPath section];
   NSLog(@"section %d, row %d", section, row);
}


- (void)dealloc {
   [super dealloc];
}


@end

