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

@synthesize analysisView, bookMovesView, boardView, whiteClockView, blackClockView, moveListView, gameController, searchStatsView;

/// init

- (id)init {
   if (self = [super init]) {
      [self setTitle: [[[NSBundle mainBundle] infoDictionary]
                         objectForKey: @"CFBundleName"]];
   }
   return self;
}


/// loadView creates and lays out all the subviews of the main window: The
/// board, the toolbar, the move list, and the small UILabels used to display
/// the engine analysis and the clocks.

- (void)loadView {

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
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

      // Clocks
      whiteClockView = [[UILabel alloc] initWithFrame: CGRectMake(8.0f, 814.0f, 185.0f, 59.0f)];
      [whiteClockView setFont: [UIFont systemFontOfSize: 25.0]];
      [whiteClockView setTextAlignment: UITextAlignmentCenter];
      [whiteClockView setText: @"White: 5:00"];
      [whiteClockView setBackgroundColor: [UIColor whiteColor]];

      blackClockView = [[UILabel alloc] initWithFrame: CGRectMake(8.0f, 881.0f, 185.0f, 59.0f)];
      [blackClockView setFont: [UIFont systemFontOfSize: 25.0]];
      [blackClockView setTextAlignment: UITextAlignmentCenter];
      [blackClockView setText: @"Black: 5:00"];
      [blackClockView setBackgroundColor: [UIColor whiteColor]];

      [contentView addSubview: whiteClockView];
      [contentView addSubview: blackClockView];

      // Move list
      moveListView =
         [[MoveListView alloc] initWithFrame:
                                  CGRectMake(203.0f, 814.0f, 760.0f-203.0f, 126.0f)];
      [moveListView setFont: [UIFont systemFontOfSize: 14.0]];
      [moveListView setEditable: NO];
      [contentView addSubview: moveListView];

      // Book moves
      bookMovesView = [[UILabel alloc] initWithFrame: CGRectMake(8.0f, 948.0f, 752.0f, 20.0f)];
      [bookMovesView setFont: [UIFont systemFontOfSize: 14.0]];
      [bookMovesView setBackgroundColor: [UIColor whiteColor]];
      [contentView addSubview: bookMovesView];
      [bookMovesView release];

      // Analysis
      analysisView = [[UILabel alloc] initWithFrame: CGRectMake(8.0f, 975.0f, 440.0f, 20.0f)];
      [analysisView setFont: [UIFont systemFontOfSize: 14.0]];
      [analysisView setBackgroundColor: [UIColor whiteColor]];
      [contentView addSubview: analysisView];

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

      button = [[UIBarButtonItem alloc] initWithTitle: @"Hint"
                                                style: UIBarButtonItemStyleBordered
                                               target: self
                                               action: @selector(toolbarButtonPressed:)];
      [button setWidth: 49.0f];
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
   }
   else { // iPhone or iPod touch
      // Content view
      CGRect appRect = [[UIScreen mainScreen] applicationFrame];
      rootView = [[RootView alloc] initWithFrame: appRect];
      appRect.origin = CGPointMake(0.0f, 0.0f);
      contentView = [[UIView alloc] initWithFrame: appRect];
      [rootView addSubview: contentView];
      [self setView: rootView];
      [rootView release];
      [contentView release];

      // Board
      boardView =
         [[BoardView alloc] initWithFrame: CGRectMake(0.0f, 18.0f, 320.0f, 320.0f)];
      [contentView addSubview: boardView];

      // Search stats
      searchStatsView =
         [[UILabel alloc] initWithFrame: CGRectMake(0.0f, 0.0f, 320.0f, 18.0f)];
      [searchStatsView setFont: [UIFont systemFontOfSize: 14.0]];
      //[searchStatsView setTextAlignment: UITextAlignmentCenter];
      [searchStatsView setBackgroundColor: [UIColor lightGrayColor]];
      [contentView addSubview: searchStatsView];
      [searchStatsView release];

      // Clocks
      whiteClockView =
         [[UILabel alloc] initWithFrame: CGRectMake(0.0f, 0.0f, 160.0f, 18.0f)];
      [whiteClockView setFont: [UIFont systemFontOfSize: 14.0]];
      [whiteClockView setTextAlignment: UITextAlignmentCenter];
      [whiteClockView setText: @"White: 5:00"];
      [whiteClockView setBackgroundColor: [UIColor lightGrayColor]];

      blackClockView =
         [[UILabel alloc] initWithFrame: CGRectMake(160.0f, 0.0f, 160.0f, 18.0f)];
      [blackClockView setFont: [UIFont systemFontOfSize: 14.0]];
      [blackClockView setTextAlignment: UITextAlignmentCenter];
      [blackClockView setText: @"Black: 5:00"];
      [blackClockView setBackgroundColor: [UIColor lightGrayColor]];

      [contentView addSubview: whiteClockView];
      [contentView addSubview: blackClockView];

      // Analysis
      analysisView =
         [[UILabel alloc] initWithFrame: CGRectMake(0.0f, 338.0f, 320.0f, 18.0f)];
      [analysisView setFont: [UIFont systemFontOfSize: 13.0]];
      [analysisView setBackgroundColor: [UIColor lightGrayColor]];
      [contentView addSubview: analysisView];

      // Book moves. Shared with analysis view on the iPhone.
      bookMovesView = analysisView;

      // Move list
      moveListView =
         [[MoveListView alloc] initWithFrame:
                                  CGRectMake(0.0f, 356.0f, 320.0f, 60.0f)];
      [moveListView setFont: [UIFont systemFontOfSize: 14.0]];
      [moveListView setEditable: NO];
      [contentView addSubview: moveListView];

      // Toolbar
      UIToolbar *toolbar =
         [[UIToolbar alloc]
            initWithFrame: CGRectMake(0.0f, 480.0f-64.0f, 320.0f, 64.0f)];
      [contentView addSubview: toolbar];

      NSMutableArray *buttons = [[NSMutableArray alloc] init];
      UIBarButtonItem *button;

      button = [[UIBarButtonItem alloc] initWithTitle: @"Game"
                                                style: UIBarButtonItemStyleBordered
                                               target: self
                                               action: @selector(toolbarButtonPressed:)];
      [button setWidth: 58.0f];
      [buttons addObject: button];
      [button release];
      button = [[UIBarButtonItem alloc] initWithTitle: @"Options"
                                                style: UIBarButtonItemStyleBordered
                                               target: self
                                               action: @selector(toolbarButtonPressed:)];
      //[button setWidth: 60.0f];
      [buttons addObject: button];
      [button release];
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
      button = [[UIBarButtonItem alloc] initWithTitle: @"Hint"
                                                style: UIBarButtonItemStyleBordered
                                               target: self
                                               action: @selector(toolbarButtonPressed:)];
      [button setWidth: 49.0f];
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
   }

   // Action sheets for menus.
   gameMenu = [[UIActionSheet alloc]
                    initWithTitle: nil
                         delegate: self
                cancelButtonTitle: @"Cancel"
                 destructiveButtonTitle: nil
                otherButtonTitles: @"New game", @"Save game", @"Load game", @"E-mail game", @"Edit position", @"Level/Game mode", nil];
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
   emailMenu = nil;
   levelsMenu = nil;
   loadMenu = nil;
   popoverMenu = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return YES;
   else if (interfaceOrientation == UIInterfaceOrientationPortrait)
      return YES;
   else
      return NO;
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
      [whiteClockView setFrame: CGRectMake(656.0f, 49.0f, 176.0f, 59.0f)];
      [blackClockView setFrame: CGRectMake(656.0f+176.0f+8.0f, 49.0f, 176.0f, 59.0f)];
      [moveListView setFrame: CGRectMake(656.0f, 116.0f, 360.0f, 573.0f)];
      [bookMovesView setFrame: CGRectMake(5.0f, 695.0f, 640.0f, 20.0f)];
      [analysisView setFrame: CGRectMake(5.0f, 721.0f, 1011.0f, 20.0f)];
      [searchStatsView setFrame: CGRectMake(656.0f, 695.0f, 360.0f, 20.0f)];
   }
   else {
      [boardView setFrame: CGRectMake(8.0f, 52.0f, 752.0f, 752.0f)];
      [whiteClockView setFrame: CGRectMake(8.0f, 814.0f, 185.0f, 59.0f)];
      [blackClockView setFrame: CGRectMake(8.0f, 881.0f, 185.0f, 59.0f)];
      [moveListView setFrame: CGRectMake(203.0f, 814.0f, 760.0f-203.0f, 126.0f)];
      [bookMovesView setFrame: CGRectMake(8.0f, 948.0f, 752.0f, 20.0f)];
      [analysisView setFrame: CGRectMake(8.0f, 975.0f, 440.0f, 20.0f)];
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
   [analysisView release];
   [boardView release];
   [whiteClockView release];
   [blackClockView release];
   [moveListView release];
   [gameMenu release];
   [newGameMenu release];
   [moveMenu release];
   [optionsMenu release];
   [saveMenu release];
   [emailMenu release];
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
   else if ([[alertView title] isEqualToString:
                                  @"Exit Stockfish and send e-mail?"]) {
      if (buttonIndex == 1)
         [[UIApplication sharedApplication]
            openURL: [[NSURL alloc] initWithString:
                                       [gameController emailPgnString]]];
   }
}


- (void)actionSheet:(UIActionSheet *)actionSheet
clickedButtonAtIndex:(NSInteger)buttonIndex {
   NSString *title = [actionSheet title];

   NSLog(@"Menu: %@ selection: %d", title, buttonIndex);
   if (actionSheet == gameMenu || [title isEqualToString: @"Game"]) {
      UIActionSheet *menu;
      switch(buttonIndex) {
      case 0:
         if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [newGameMenu showFromBarButtonItem: gameButton animated: YES];
         else {
            menu =
               [[UIActionSheet alloc] initWithTitle: @"New game"
                                           delegate: self
                                  cancelButtonTitle: @"Cancel"
                             destructiveButtonTitle: nil
                                  otherButtonTitles:
                                         @"Play white", @"Play black", @"Play both",
                                      @"Analysis", nil];
            [menu showInView: contentView];
            [menu release];
         }
         break;
      case 1:
         [self showSaveGameMenu];
         break;
      case 2:
         [self showLoadGameMenu];
         break;
      case 3:
         [self showEmailGameMenu];
         break;
      case 4:
         [self editPosition];
         break;
      case 5:
         [self showLevelsMenu];
         break;
      case 6:
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
                                         message: ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)?
                                                   @"You can also take back moves by swiping your finger from right to left in the move list window." :
                                                   @"You can also take back moves by swiping your finger from right to left in the move list area below the board.")
                                        delegate: self
                               cancelButtonTitle: nil
                               otherButtonTitles: @"OK", nil] autorelease]
               show];
         [gameController takeBackMove];
         break;
      case 1: // Step forward
         if ([[Options sharedOptions] displayMoveGestureStepForwardHint])
            [[[[UIAlertView alloc] initWithTitle: @"Hint:"
                                         message: ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)?
                                                   @"You can also step forward in the game by swiping your finger from left to right in the move list window." :
                                                   @"You can also step forward in the game by swiping your finger from left to right in the move list area below the board.")
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
      switch (buttonIndex) {
      case 0:
         NSLog(@"new game with white");
         [[Options sharedOptions] setGameMode: GAME_MODE_COMPUTER_BLACK];
         [gameController setGameMode: GAME_MODE_COMPUTER_BLACK];
         [gameController startNewGame];
         break;
      case 1:
         NSLog(@"new game with black");
         [[Options sharedOptions] setGameMode: GAME_MODE_COMPUTER_WHITE];
         [gameController setGameMode: GAME_MODE_COMPUTER_WHITE];
         [gameController startNewGame];
         break;
      case 2:
         NSLog(@"new game (both)");
         [[Options sharedOptions] setGameMode: GAME_MODE_TWO_PLAYER];
         [gameController setGameMode: GAME_MODE_TWO_PLAYER];
         [gameController startNewGame];
         break;
      case 3:
         NSLog(@"new game (analysis)");
         [[Options sharedOptions] setGameMode: GAME_MODE_ANALYSE];
         [gameController setGameMode: GAME_MODE_ANALYSE];
         [gameController startNewGame];
         break;
      default:
         NSLog(@"not implemented yet");
      }
   }
}


- (void)toolbarButtonPressed:(id)sender {
   NSString *title = [sender title];

   // Ignore duplicate presses on the "Game" and "Move" buttons:
   if ([gameMenu isVisible] && [title isEqualToString: @"Game"] ||
       [moveMenu isVisible] && [title isEqualToString: @"Move"])
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
   if (emailMenu != nil) {
      [emailMenu dismissPopoverAnimated: YES];
      [emailMenu release];
      emailMenu = nil;
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
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
         [gameMenu showFromBarButtonItem: sender animated: YES];
      }
      else {
         UIActionSheet *menu =
            [[UIActionSheet alloc]
              initWithTitle: @"Game"
                   delegate: self
               cancelButtonTitle: @"Cancel"
               destructiveButtonTitle: nil
               otherButtonTitles:
                  @"New game", @"Save game", @"Load game", @"E-mail game", @"Edit position", @"Level/Game mode", nil];
         [menu showInView: contentView];
         [menu release];
      }
   }
   else if ([title isEqualToString: @"Options"])
      [self showOptionsMenu];
   else if ([title isEqualToString: @"Flip"])
      [gameController rotateBoard];
   else if ([title isEqualToString: @"Move"]) {
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
         [moveMenu showFromBarButtonItem: sender animated: YES];
      }
      else {
         UIActionSheet *menu =
            [[UIActionSheet alloc]
               initWithTitle: @"Move"
                    delegate: self
               cancelButtonTitle: @"Cancel"
               destructiveButtonTitle: nil
               otherButtonTitles:
                  @"Take back", @"Step forward", @"Take back all", @"Step forward all", @"Move now", nil];
         [menu showInView: contentView];
         [menu release];
      }
   }
   else if ([title isEqualToString: @"Hint"])
      [gameController showHint];
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
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      optionsMenu = [[UIPopoverController alloc]
                       initWithContentViewController: navigationController];
      [optionsMenu presentPopoverFromBarButtonItem: optionsButton
                          permittedArrowDirections: UIPopoverArrowDirectionAny
                                          animated: YES];
   }
   else {
      CGRect r = [[navigationController view] frame];
      // Why do I suddenly have to use -20.0f for the Y coordinate below?
      // 0.0f seems right, and used to work in SDK 2.x.
      r.origin = CGPointMake(0.0f, -20.0f);
      [[navigationController view] setFrame: r];
      [rootView insertSubview: [navigationController view] atIndex: 0];
      [rootView flipSubviewsLeft];
   }
}


- (void)optionsMenuDonePressed {
   NSLog(@"options menu done");
   if ([[Options sharedOptions] bookVarietyWasChanged])
      [gameController showBookMoves];
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [optionsMenu dismissPopoverAnimated: YES];
      [optionsMenu release];
      optionsMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
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
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      levelsMenu = [[UIPopoverController alloc]
                      initWithContentViewController: navigationController];
      [levelsMenu presentPopoverFromBarButtonItem: gameButton
                         permittedArrowDirections: UIPopoverArrowDirectionAny
                                         animated: YES];
   }
   else {
      CGRect r = [[navigationController view] frame];
      // Why do I suddenly have to use -20.0f for the Y coordinate below?
      // 0.0f seems right, and used to work in SDK 2.x.
      r.origin = CGPointMake(0.0f, -20.0f);
      [[navigationController view] setFrame: r];
      [rootView insertSubview: [navigationController view] atIndex: 0];
      [rootView flipSubviewsLeft];
   }
}


- (void)levelWasChanged {
   [gameController setGameLevel: [[Options sharedOptions] gameLevel]];
}


- (void)gameModeWasChanged {
   [gameController setGameMode: [[Options sharedOptions] gameMode]];
}

- (void)levelsMenuDonePressed {
   NSLog(@"options menu done");
   /*
     if ([[Options sharedOptions] gameLevelWasChanged])
     [gameController setGameLevel: [[Options sharedOptions] gameLevel]];
     if ([[Options sharedOptions] gameModeWasChanged])
     [gameController setGameMode: [[Options sharedOptions] gameMode]];
   */

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [levelsMenu dismissPopoverAnimated: YES];
      [levelsMenu release];
      levelsMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
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

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      popoverMenu = [[UIPopoverController alloc]
                       initWithContentViewController: navigationController];
      //[popoverMenu setPopoverContentSize: CGSizeMake(320.0f, 460.0f)];
      [popoverMenu presentPopoverFromBarButtonItem: gameButton
                          permittedArrowDirections: UIPopoverArrowDirectionAny
                                          animated: NO];
   }
   else {
      CGRect r = [[navigationController view] frame];
      // Why do I suddenly have to use -20.0f for the Y coordinate below?
      // 0.0f seems right, and used to work in SDK 2.x.
      r.origin = CGPointMake(0.0f, -20.0f);
      [[navigationController view] setFrame: r];
      [rootView insertSubview: [navigationController view] atIndex: 0];
      [rootView flipSubviewsLeft];
   }
}


- (void)editPositionCancelPressed {
   NSLog(@"edit position cancel");
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [popoverMenu dismissPopoverAnimated: YES];
      [popoverMenu release];
      popoverMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
}


- (void)editPositionDonePressed:(NSString *)fen {
   NSLog(@"edit position done: %@", fen);
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [popoverMenu dismissPopoverAnimated: YES];
      [popoverMenu release];
      popoverMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
   [boardView hideLastMove];
   [gameController gameFromFEN: fen];
}


- (void)showSaveGameMenu {
   GameDetailsTableController *gdtc =
      [[GameDetailsTableController alloc]
         initWithBoardViewController: self
                                game: [gameController game]
                               email: NO];
   navigationController =
      [[UINavigationController alloc] initWithRootViewController: gdtc];
   [gdtc release];
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      saveMenu = [[UIPopoverController alloc]
                   initWithContentViewController: navigationController];
      [saveMenu presentPopoverFromBarButtonItem: gameButton
                       permittedArrowDirections: UIPopoverArrowDirectionAny
                                       animated: YES];
   }
   else {
      CGRect r = [[navigationController view] frame];
      // Why do I suddenly have to use -20.0f for the Y coordinate below?
      // 0.0f seems right, and used to work in SDK 2.x.
      r.origin = CGPointMake(0.0f, -20.0f);
      [[navigationController view] setFrame: r];
      [rootView insertSubview: [navigationController view] atIndex: 0];
      [rootView flipSubviewsLeft];
   }
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
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [saveMenu dismissPopoverAnimated: YES];
      [saveMenu release];
      saveMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
   NSLog(@"save game done");
}


- (void)saveMenuCancelPressed {
   NSLog(@"save game canceled");
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [saveMenu dismissPopoverAnimated: YES];
      [saveMenu release];
      saveMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
}


- (void)showLoadGameMenu {
   LoadFileListController *lflc =
      [[LoadFileListController alloc] initWithBoardViewController: self];
   navigationController =
      [[UINavigationController alloc] initWithRootViewController: lflc];
   [lflc release];
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      loadMenu = [[UIPopoverController alloc]
                    initWithContentViewController: navigationController];
      [loadMenu presentPopoverFromBarButtonItem: gameButton
                       permittedArrowDirections: UIPopoverArrowDirectionAny
                                       animated: YES];
   }
   else {
      CGRect r = [[navigationController view] frame];
      // Why do I suddenly have to use -20.0f for the Y coordinate below?
      // 0.0f seems right, and used to work in SDK 2.x.
      r.origin = CGPointMake(0.0f, -20.0f);
      [[navigationController view] setFrame: r];
      [rootView insertSubview: [navigationController view] atIndex: 0];
      [rootView flipSubviewsLeft];
   }
}


- (void)loadMenuCancelPressed {
   NSLog(@"load game canceled");
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [loadMenu dismissPopoverAnimated: YES];
      [loadMenu release];
      loadMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
}


- (void)loadMenuDonePressedWithGame:(NSString *)gameString {
   NSLog(@"load menu done, gameString = %@", gameString);
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [loadMenu dismissPopoverAnimated: YES];
      [loadMenu release];
      loadMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
   [gameController gameFromPGNString: gameString];
   [boardView hideLastMove];
}


- (void)showEmailGameMenu {
   GameDetailsTableController *gdtc =
      [[GameDetailsTableController alloc]
         initWithBoardViewController: self
                                game: [gameController game]
                               email: YES];
   navigationController =
      [[UINavigationController alloc] initWithRootViewController: gdtc];
   [gdtc release];
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      emailMenu = [[UIPopoverController alloc]
                    initWithContentViewController: navigationController];
      [emailMenu presentPopoverFromBarButtonItem: gameButton
                        permittedArrowDirections: UIPopoverArrowDirectionAny
                                        animated: YES];
   }
   else {
      CGRect r = [[navigationController view] frame];
      // Why do I suddenly have to use -20.0f for the Y coordinate below?
      // 0.0f seems right, and used to work in SDK 2.x.
      r.origin = CGPointMake(0.0f, -20.0f);
      [[navigationController view] setFrame: r];
      [rootView insertSubview: [navigationController view] atIndex: 0];
      [rootView flipSubviewsLeft];
   }
}


- (void)emailMenuDonePressed {
   NSLog(@"email game done");
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [emailMenu dismissPopoverAnimated: YES];
      [emailMenu release];
      emailMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
   [[[[UIAlertView alloc] initWithTitle: @"Exit Stockfish and send e-mail?"
                                message: @""
                               delegate: self
                      cancelButtonTitle: @"Cancel"
                      otherButtonTitles: @"OK", nil] autorelease]
      show];
}


- (void)emailMenuCancelPressed {
   NSLog(@"email game canceled");
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      [emailMenu dismissPopoverAnimated: YES];
      [emailMenu release];
      emailMenu = nil;
   }
   else {
      [rootView flipSubviewsRight];
      [[navigationController view] removeFromSuperview];
   }
   [navigationController release];
}


- (void)stopActivityIndicator {
   if (activityIndicator) {
      [activityIndicator stopAnimating];
      [activityIndicator removeFromSuperview];
      activityIndicator = nil;
   }
}


- (void)hideAnalysis {
   [analysisView setText: @""];
   [searchStatsView setText: @""];
   if ([[Options sharedOptions] showBookMoves])
      [gameController showBookMoves];
}


- (void)hideBookMoves {
   if ([[analysisView text] hasPrefix: @"  Book"])
      [analysisView setText: @""];
}


- (void)showBookMoves {
   [gameController showBookMoves];
}


- (void)connectToServer {
   [gameController connectToServer];
}


- (void)disconnectFromServer {
   [gameController disconnectFromServer];
}


- (BOOL)isConnectedToServer {
   return [gameController isConnectedToServer];
}


@end
