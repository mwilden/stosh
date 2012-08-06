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
#import "GameController.h"
#import "GameDetailsTableController.h"
#import "LevelViewController.h"
#import "LoadFileListController.h"
#import "MoveListView.h"
#import "Options.h"
#import "OptionsViewController.h"
#import "PGN.h"
#import "SetupViewController.h"

@implementation BoardViewController

@synthesize boardView, moveListView, gameController, searchStatsView;

/// init

- (id)init {
   if (self = [super init]) {
      [self setTitle: [[[NSBundle mainBundle] infoDictionary]
                         objectForKey: @"CFBundleName"]];
   }
   return self;
}


/// loadView creates and lays out all the subviews of the main window: The
/// board, the toolbar, and the move list.

- (void)loadView {

  // Content view
  CGRect appRect = [[UIScreen mainScreen] applicationFrame];
  rootView = [[RootView alloc] initWithFrame: appRect];
  [rootView setAutoresizesSubviews: YES];
  [rootView setAutoresizingMask: (UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleHeight)];
  appRect.origin = CGPointMake(0.0f, 0.0f);
  contentView = [[UIView alloc] initWithFrame: appRect];
  [contentView setAutoresizesSubviews: YES];
  [contentView setAutoresizingMask: (UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight)];
  [contentView setBackgroundColor: [UIColor lightGrayColor]];
  [rootView addSubview: contentView];
  [self setView: rootView];
  [rootView release];
  [contentView release];

  // Board
  //boardView = [[BoardView alloc] initWithFrame: CGRectMake(0.0f, 44.0f, 768.0f, 768.0f)];
  boardView = [[BoardView alloc] initWithFrame: CGRectMake(8.0f, 52.0f, 752.0f, 752.0f)];
  [contentView addSubview: boardView];

  // Move list
  moveListView =
     [[MoveListView alloc] initWithFrame:
                              CGRectMake(203.0f, 814.0f, 760.0f-203.0f, 126.0f)];
  [moveListView setFont: [UIFont systemFontOfSize: 14.0]];
  [moveListView setEditable: NO];
  [contentView addSubview: moveListView];

  // Search stats
  searchStatsView = [[UILabel alloc] initWithFrame: CGRectMake(458.0f, 975.0f, 302.0f, 20.0f)];
  [searchStatsView setFont: [UIFont systemFontOfSize: 14.0]];
  //[searchStatsView setTextAlignment: UITextAlignmentCenter];
  [searchStatsView setBackgroundColor: [UIColor whiteColor]];
  [contentView addSubview: searchStatsView];
  [searchStatsView release];

  // Toolbar
  UIToolbar *toolbar =
     [[UIToolbar alloc]
        initWithFrame: CGRectMake(0.0f, 0.0f, 320.0f, 44.0f)];
  [contentView addSubview: toolbar];
  [toolbar setAutoresizingMask: UIViewAutoresizingFlexibleWidth];

  NSMutableArray *buttons = [[NSMutableArray alloc] init];
  UIBarButtonItem *button;

  button = [[UIBarButtonItem alloc] initWithTitle: @"Game"
                                            style: UIBarButtonItemStyleBordered
                                           target: self
                                           action: @selector(toolbarButtonPressed:)];
  [button setWidth: 58.0f];
  [buttons addObject: button];
  [button release];
  gameButton = button;

  button = [[UIBarButtonItem alloc] initWithTitle: @"Options"
                                            style: UIBarButtonItemStyleBordered
                                           target: self
                                           action: @selector(toolbarButtonPressed:)];
  //[button setWidth: 60.0f];
  [buttons addObject: button];
  [button release];
  optionsButton = button;

  button = [[UIBarButtonItem alloc] initWithTitle: @"Flip"
                                            style: UIBarButtonItemStyleBordered
                                           target: self
                                           action: @selector(toolbarButtonPressed:)];
  [buttons addObject: button];
  [button release];

  button = [[UIBarButtonItem alloc] initWithTitle: @"Move"
                                            style: UIBarButtonItemStyleBordered
                                           target: self
                                           action: @selector(toolbarButtonPressed:)];
  [button setWidth: 53.0f];
  [buttons addObject: button];
  [button release];

  [toolbar setItems: buttons animated: YES];
  [buttons release];
  [toolbar sizeToFit];
  [toolbar release];

  [contentView bringSubviewToFront: boardView];

  // Activity indicator
  activityIndicator =
     [[UIActivityIndicatorView alloc] initWithFrame: CGRectMake(0,0,30,30)];
  [activityIndicator setCenter: CGPointMake(160.0f, 180.0f)];
  [activityIndicator
     setActivityIndicatorViewStyle: UIActivityIndicatorViewStyleWhite];
  [contentView addSubview: activityIndicator];
  [activityIndicator startAnimating];
  [activityIndicator release];

   // Action sheets for menus.
   gameMenu = [[UIActionSheet alloc]
                    initWithTitle: nil
                         delegate: self
                cancelButtonTitle: @"Cancel"
                 destructiveButtonTitle: nil
                otherButtonTitles: @"New game", @"Save game", @"Load game", @"Edit position", @"Level/Game mode", nil];
   newGameMenu = [[UIActionSheet alloc] initWithTitle: nil
                                             delegate: self
                                    cancelButtonTitle: @"Cancel"
                               destructiveButtonTitle: nil
                                    otherButtonTitles:
                                           @"Play white", @"Play black", @"Play both", @"Analysis", nil];
   moveMenu = [[UIActionSheet alloc] initWithTitle: nil
                                          delegate: self
                                 cancelButtonTitle: @"Cancel"
                            destructiveButtonTitle: nil
                                 otherButtonTitles:
                                        @"Take back", @"Step forward", @"Take back all", @"Step forward all", @"Move now", nil];
   optionsMenu = nil;
   saveMenu = nil;
   levelsMenu = nil;
   loadMenu = nil;
   popoverMenu = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration {
   NSLog(@"will rotate!");
   //[rootView sizeToFit];
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation {
   NSLog(@"did rotate, preparing to move and resize views");
   if ([self interfaceOrientation] == UIInterfaceOrientationLandscapeLeft ||
       [self interfaceOrientation] == UIInterfaceOrientationLandscapeRight) {
      [boardView setFrame: CGRectMake(5.0f, 49.0f, 640.0f, 640.0f)];
      [moveListView setFrame: CGRectMake(656.0f, 116.0f, 360.0f, 573.0f)];
      [searchStatsView setFrame: CGRectMake(656.0f, 695.0f, 360.0f, 20.0f)];
   }
   else {
      [boardView setFrame: CGRectMake(8.0f, 52.0f, 752.0f, 752.0f)];
      [moveListView setFrame: CGRectMake(203.0f, 814.0f, 760.0f-203.0f, 126.0f)];
      [searchStatsView setFrame: CGRectMake(458.0f, 975.0f, 302.0f, 20.0f)];
   }
   [gameController updateMoveList];
}

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
[super viewDidLoad];
}
*/

 /*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)dealloc {
   [contentView release];
   [boardView release];
   [moveListView release];
   [gameMenu release];
   [newGameMenu release];
   [moveMenu release];
   [optionsMenu release];
   [saveMenu release];
   [levelsMenu release];
   [loadMenu release];
   [popoverMenu release];
   [super dealloc];
}


- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
   if ([[alertView title] isEqualToString: @"Start new game?"]) {
      if (buttonIndex == 1)
         [gameController startNewGame];
   }
}


- (void)actionSheet:(UIActionSheet *)actionSheet
clickedButtonAtIndex:(NSInteger)buttonIndex {
   NSString *title = [actionSheet title];

   NSLog(@"Menu: %@ selection: %d", title, buttonIndex);
   if (actionSheet == gameMenu || [title isEqualToString: @"Game"]) {
      switch(buttonIndex) {
      case 0:
        [newGameMenu showFromBarButtonItem: gameButton animated: YES];
         break;
      case 1:
         [self showSaveGameMenu];
         break;
      case 2:
         [self showLoadGameMenu];
         break;
      case 3:
         [self editPosition];
         break;
      case 4:
         [self showLevelsMenu];
         break;
      case 5:
         break;
      default:
         NSLog(@"Not implemented yet");
      }
   }
   else if (actionSheet == moveMenu || [title isEqualToString: @"Move"]) {
      switch(buttonIndex) {
      case 0: // Take back
         if ([[Options sharedOptions] displayMoveGestureTakebackHint])
            [[[[UIAlertView alloc] initWithTitle: @"Hint:"
                                         message: (@"You can also take back moves by swiping your finger from right to left in the move list window.")
                                        delegate: self
                               cancelButtonTitle: nil
                               otherButtonTitles: @"OK", nil] autorelease]
               show];
         [gameController takeBackMove];
         break;
      case 1: // Step forward
         if ([[Options sharedOptions] displayMoveGestureStepForwardHint])
            [[[[UIAlertView alloc] initWithTitle: @"Hint:"
                                         message: (@"You can also step forward in the game by swiping your finger from left to right in the move list window.")
                                        delegate: self
                               cancelButtonTitle: nil
                               otherButtonTitles: @"OK", nil] autorelease]
               show];
         [gameController replayMove];
         break;
      case 2: // Take back all
         [gameController takeBackAllMoves];
         break;
      case 3: // Step forward all
         [gameController replayAllMoves];
         break;
      case 4: // Move now
         if ([gameController computersTurnToMove]) {
            if ([gameController engineIsThinking])
               [gameController engineMoveNow];
            else
               [gameController engineGo];
         }
         else
            [gameController startThinking];
         break;
      case 5:
         break;
      default:
         NSLog(@"Not implemented yet");
      }
   }
   else if (actionSheet == newGameMenu || [title isEqualToString: @"New game"]) {
     [gameController startNewGame];
   }
}


- (void)toolbarButtonPressed:(id)sender {
   NSString *title = [sender title];

   // Ignore duplicate presses on the "Game" and "Move" buttons:
   if (([gameMenu isVisible] && [title isEqualToString: @"Game"]) ||
       ([moveMenu isVisible] && [title isEqualToString: @"Move"]))
      return;

   // Dismiss action sheet popovers, if visible:
   if ([gameMenu isVisible] && ![title isEqualToString: @"Game"])
      [gameMenu dismissWithClickedButtonIndex: -1 animated: YES];
   if ([newGameMenu isVisible])
      [newGameMenu dismissWithClickedButtonIndex: -1 animated: YES];
   if ([moveMenu isVisible])
      [moveMenu dismissWithClickedButtonIndex: -1 animated: YES];
   if (optionsMenu != nil) {
      [optionsMenu dismissPopoverAnimated: YES];
      [optionsMenu release];
      optionsMenu = nil;
   }
   if (levelsMenu != nil) {
      [levelsMenu dismissPopoverAnimated: YES];
      [levelsMenu release];
      levelsMenu = nil;
   }
   if (saveMenu != nil) {
      [saveMenu dismissPopoverAnimated: YES];
      [saveMenu release];
      saveMenu = nil;
   }
   if (loadMenu != nil) {
      [loadMenu dismissPopoverAnimated: YES];
      [loadMenu release];
      loadMenu = nil;
   }
   if (popoverMenu != nil) {
      [popoverMenu dismissPopoverAnimated: YES];
      [popoverMenu release];
      popoverMenu = nil;
   }

   if ([title isEqualToString: @"Game"]) {
      [gameMenu showFromBarButtonItem: sender animated: YES];
   }
   else if ([title isEqualToString: @"Options"])
      [self showOptionsMenu];
   else if ([title isEqualToString: @"Flip"])
      [gameController rotateBoard];
   else if ([title isEqualToString: @"Move"]) {
     [moveMenu showFromBarButtonItem: sender animated: YES];
   }
   else if ([title isEqualToString: @"New"])
      [gameController startNewGame];
   else
      NSLog(@"%@", [sender title]);
}


- (void)showOptionsMenu {
   OptionsViewController *ovc;
   ovc = [[OptionsViewController alloc] initWithBoardViewController: self];
   navigationController =
      [[UINavigationController alloc]
         initWithRootViewController: ovc];
   [ovc release];
   optionsMenu = [[UIPopoverController alloc]
                   initWithContentViewController: navigationController];
   [optionsMenu presentPopoverFromBarButtonItem: optionsButton
                      permittedArrowDirections: UIPopoverArrowDirectionAny
                                      animated: YES];
}


- (void)optionsMenuDonePressed {
   NSLog(@"options menu done");
   [optionsMenu dismissPopoverAnimated: YES];
   [optionsMenu release];
   optionsMenu = nil;
   [navigationController release];
}


- (void)showLevelsMenu {
   NSLog(@"levels menu");
   LevelViewController *lvc;
   lvc = [[LevelViewController alloc] initWithBoardViewController: self];
   navigationController =
      [[UINavigationController alloc]
         initWithRootViewController: lvc];
   [lvc release];
  levelsMenu = [[UIPopoverController alloc]
                  initWithContentViewController: navigationController];
  [levelsMenu presentPopoverFromBarButtonItem: gameButton
                     permittedArrowDirections: UIPopoverArrowDirectionAny
                                     animated: YES];
}


- (void)levelWasChanged {
   [gameController setGameLevel: [[Options sharedOptions] gameLevel]];
}


- (void)levelsMenuDonePressed {
   NSLog(@"options menu done");
  [levelsMenu dismissPopoverAnimated: YES];
  [levelsMenu release];
  levelsMenu = nil;
   [navigationController release];
}


- (void)editPosition {
   SetupViewController *svc =
      [[SetupViewController alloc]
         initWithBoardViewController: self
                                 fen: [[gameController game] currentFEN]];
   navigationController =
      [[UINavigationController alloc] initWithRootViewController: svc];
   [svc release];

  popoverMenu = [[UIPopoverController alloc]
                   initWithContentViewController: navigationController];
  [popoverMenu presentPopoverFromBarButtonItem: gameButton
                      permittedArrowDirections: UIPopoverArrowDirectionAny
                                      animated: NO];
}


- (void)editPositionCancelPressed {
   NSLog(@"edit position cancel");
  [popoverMenu dismissPopoverAnimated: YES];
  [popoverMenu release];
  popoverMenu = nil;
   [navigationController release];
}


- (void)editPositionDonePressed:(NSString *)fen {
   NSLog(@"edit position done: %@", fen);
   [popoverMenu dismissPopoverAnimated: YES];
   [popoverMenu release];
   popoverMenu = nil;
   [navigationController release];
   [boardView hideLastMove];
   [gameController gameFromFEN: fen];
}


- (void)showSaveGameMenu {
   GameDetailsTableController *gdtc =
      [[GameDetailsTableController alloc]
         initWithBoardViewController: self
                                game: [gameController game]];
   navigationController =
      [[UINavigationController alloc] initWithRootViewController: gdtc];
   [gdtc release];
  saveMenu = [[UIPopoverController alloc]
               initWithContentViewController: navigationController];
  [saveMenu presentPopoverFromBarButtonItem: gameButton
                   permittedArrowDirections: UIPopoverArrowDirectionAny
                                   animated: YES];
}


- (void)saveMenuDonePressed {
   NSLog(@"save game done");
   FILE *pgnFile =
      fopen([[PGN_DIRECTORY
                stringByAppendingPathComponent: [[Options sharedOptions]
                                                   saveGameFile]] UTF8String],
            "a");
   if (pgnFile != NULL) {
      fprintf(pgnFile, "%s", [[[gameController game] pgnString] UTF8String]);
      fclose(pgnFile);
   }
   [saveMenu dismissPopoverAnimated: YES];
   [saveMenu release];
   saveMenu = nil;
   [navigationController release];
   NSLog(@"save game done");
}


- (void)saveMenuCancelPressed {
   NSLog(@"save game canceled");
   [saveMenu dismissPopoverAnimated: YES];
   [saveMenu release];
   saveMenu = nil;
   [navigationController release];
}


- (void)showLoadGameMenu {
   LoadFileListController *lflc =
      [[LoadFileListController alloc] initWithBoardViewController: self];
   navigationController =
      [[UINavigationController alloc] initWithRootViewController: lflc];
   [lflc release];
   loadMenu = [[UIPopoverController alloc]
                initWithContentViewController: navigationController];
   [loadMenu presentPopoverFromBarButtonItem: gameButton
                   permittedArrowDirections: UIPopoverArrowDirectionAny
                                   animated: YES];
}


- (void)loadMenuCancelPressed {
   NSLog(@"load game canceled");
   [loadMenu dismissPopoverAnimated: YES];
   [loadMenu release];
   loadMenu = nil;
   [navigationController release];
}


- (void)loadMenuDonePressedWithGame:(NSString *)gameString {
   NSLog(@"load menu done, gameString = %@", gameString);
   [loadMenu dismissPopoverAnimated: YES];
   [loadMenu release];
   loadMenu = nil;
   [navigationController release];
   [gameController gameFromPGNString: gameString];
   [boardView hideLastMove];
}


- (void)stopActivityIndicator {
   if (activityIndicator) {
      [activityIndicator stopAnimating];
      [activityIndicator removeFromSuperview];
      activityIndicator = nil;
   }
}


@end
