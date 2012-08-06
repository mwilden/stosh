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

#import "AboutController.h"
#import "BoardViewController.h"
#import "Options.h"
#import "OptionsViewController.h"

@implementation OptionsViewController

@synthesize boardViewController;

- (id)initWithBoardViewController:(BoardViewController *)bvc {
   if (self = [super initWithStyle: UITableViewStyleGrouped]) {
      [self setTitle: nil];
      boardViewController = bvc;
   }
   return self;
}


- (void)loadView {
   [super loadView];
   [[self navigationItem] setRightBarButtonItem:
                             [[[UIBarButtonItem alloc]
                                 initWithTitle: @"Done"
                                         style: UIBarButtonItemStylePlain
                                        target: boardViewController
                                        action: @selector(optionsMenuDonePressed)]
                                autorelease]];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 5;
}


- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
   switch(section) {
   case 0: return 1;
   case 1: return 5;
   case 2: return 4;
   case 3: return 1;
   case 4: return 1;
   }
   return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   NSInteger row = [indexPath row];
   NSInteger section = [indexPath section];

   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: nil];
   if (cell == nil)
      cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1
                                     reuseIdentifier: nil]
                autorelease];

   if (section == 4) {
      if (row == 0) {
         [[cell textLabel] setText: @"About/Help"];
         [cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
      }
   }
   else {
      [[cell textLabel] setText: [NSString stringWithFormat: @"section %d, row %d",
                                           section, row]];
   }
   return cell;
}

@end
