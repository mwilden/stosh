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
#import "Options.h"
#import "OptionsViewController.h"
#import "RemoteEngineHelpController.h"
#import "RemoteEngineTableController.h"
#import "RemoteEngineTextFieldController.h"

@implementation RemoteEngineTableController

- (id)initWithParentViewController:(OptionsViewController *)ovc {
   if (self = [super initWithStyle: UITableViewStyleGrouped]) {
      serverName = [[Options sharedOptions] serverName];
      serverPort = [[Options sharedOptions] serverPort];
      parentController = ovc;
   }
   return self;
}


- (void)loadView {
   [super loadView];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
   return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
   switch(section) {
   case 0: return 3;
   case 1: return 1;
   }
   return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   NSInteger row = [indexPath row];
   NSInteger section = [indexPath section];

   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"any-cell"];
   if (cell == nil)
      cell = [[[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1
                                     reuseIdentifier: @"any-cell"]
                autorelease];

   if (section == 0) {
      if (row == 0) {
         [[cell textLabel] setText: @"Server IP address"];
         [[cell detailTextLabel] setText: [[Options sharedOptions] serverName]];
         [cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
      }
      else if (row == 1) {
         [[cell textLabel] setText: @"Server port"];
         [[cell detailTextLabel] setText:
                                    [NSString stringWithFormat: @"%d",
                                              [[Options sharedOptions] serverPort]]];
         [cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
      }
      else if (row == 2) {
         [[cell textLabel] setText: @"Connected"];
         UISwitch *sw;
         sw = [[UISwitch alloc] initWithFrame: CGRectMake(4.0f, 16.0f, 10.0f, 28.0f)];
         [sw setOn: [[parentController boardViewController] isConnectedToServer]];
         [sw setEnabled: ![[[Options sharedOptions] serverName] isEqualToString: @""]];
         [sw addTarget: self action: @selector(toggleConnected:)
             forControlEvents:UIControlEventValueChanged];
         [cell setAccessoryView: sw];
         [sw release];
      }
   }
   else if (section == 1) {
      if (row == 0) {
         [[cell textLabel] setText: @"Help"];
         [cell setAccessoryType: UITableViewCellAccessoryDisclosureIndicator];
      }
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

   [self performSelector: @selector(deselect:) withObject: tableView
              afterDelay: 0.1f];

   if (section == 0) {
      RemoteEngineTextFieldController *retfc;
      if (row == 0) {
         retfc = [[RemoteEngineTextFieldController alloc]
                    initWithRemoteEngineTableController: self
                                              fieldName: @"Server IP address"];
         [[self navigationController] pushViewController: retfc
                                                animated: YES];
         [retfc release];
      }
      else if (row == 1) {
         retfc = [[RemoteEngineTextFieldController alloc]
                    initWithRemoteEngineTableController: self
                                              fieldName: @"Server port"];
         [[self navigationController] pushViewController: retfc
                                                animated: YES];
         [retfc release];
      }
   }
   else if (section == 1) {
      if (row == 0) {
         RemoteEngineHelpController *rehc;
         rehc = [[RemoteEngineHelpController alloc] init];
         [[self navigationController] pushViewController: rehc animated: YES];
         [rehc release];
      }
   }
}


- (void)deselect:(UITableView *)tableView {
   [tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow]
                            animated: YES];
}


- (void)toggleConnected:(id)sender {
   if ([sender isOn])
      [[parentController boardViewController] connectToServer];
   else
      [[parentController boardViewController] disconnectFromServer];
   [parentController updateTableCells];
}


- (void)updateTableCells {
   [[self tableView] reloadData];
}


- (void)dealloc {
   //[serverName release];
   [super dealloc];
}


@end
