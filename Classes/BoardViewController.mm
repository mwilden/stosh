#import "BoardViewController.h"
#import "GameController.h"
#import "MoveListView.h"
#import "Options.h"
#import "OptionsViewController.h"
#import "PGN.h"
#import "SetupViewController.h"

@implementation BoardViewController

@synthesize boardView, moveListView, gameController;

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
  appRect.origin = CGPointMake(0.0f, 0.0f);
  contentView = [[UIView alloc] initWithFrame: appRect];
  [contentView setAutoresizesSubviews: YES];
  [contentView setAutoresizingMask: (UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight)];
  [contentView setBackgroundColor: [UIColor lightGrayColor]];
  [self setView: contentView];
  [contentView release];

  // Board
  boardView = [[BoardView alloc] initWithFrame: CGRectMake(8.0f, 52.0f, 752.0f, 752.0f)];
  [contentView addSubview: boardView];

  // Move list
  moveListView =
     [[MoveListView alloc] initWithFrame:
                              CGRectMake(203.0f, 814.0f, 760.0f-203.0f, 126.0f)];
  [moveListView setFont: [UIFont systemFontOfSize: 14.0]];
  [moveListView setEditable: NO];
  [contentView addSubview: moveListView];

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

   // Action sheets for menus.
   gameMenu = [[UIActionSheet alloc]
                    initWithTitle: nil
                         delegate: self
                cancelButtonTitle: @"Cancel"
                 destructiveButtonTitle: nil
                otherButtonTitles: @"New game", @"Edit position",  nil];
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
   popoverMenu = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
   [contentView release];
   [boardView release];
   [moveListView release];
   [gameMenu release];
   [newGameMenu release];
   [moveMenu release];
   [optionsMenu release];
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
         [self editPosition];
         break;
      default:
         NSLog(@"Not implemented yet");
      }
   }
   else if (actionSheet == moveMenu || [title isEqualToString: @"Move"]) {
      switch(buttonIndex) {
      case 0: // Take back
         [gameController takeBackMove];
         break;
      case 1: // Step forward
         [gameController replayMove];
         break;
      case 2: // Take back all
         [gameController takeBackAllMoves];
         break;
      case 3: // Step forward all
         [gameController replayAllMoves];
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

@end
