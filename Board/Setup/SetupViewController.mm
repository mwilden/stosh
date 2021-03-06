#import "BoardViewController.h"
#import "SelectedPieceView.h"
#import "SetupBoardView.h"
#import "SetupViewController.h"
#import "SideToMoveController.h"

@implementation SetupViewController

@synthesize boardViewController;

- (id)initWithBoardViewController:(BoardViewController *)bvc
                              fen:(NSString *)aFen {
   if (self = [super init]) {
      [self setTitle: @"Board"];
      boardViewController = bvc;
      fen = [aFen retain];
      [self setContentSizeForViewInPopover: CGSizeMake(320.0f, 418.0f)];
   }
   return self;
}


- (void)loadView {
   UIView *contentView;
   CGRect r = [[UIScreen mainScreen] applicationFrame];
   contentView = [[UIView alloc] initWithFrame: r];
   [self setView: contentView];
   [contentView setBackgroundColor: [UIColor whiteColor]];

   // Create a UISegmentedControl as a menu at the top of the screen
   NSArray *buttonNames =
      [NSArray arrayWithObjects:
                  @"Clear", @"Cancel", @"Done", nil];
   menu = [[UISegmentedControl alloc] initWithItems: buttonNames];
   [menu setMomentary: YES];
   [menu setSegmentedControlStyle: UISegmentedControlStyleBar];
   [menu setFrame: CGRectMake(0.0f, 0.0f, 300.0f, 20.0f)];
   [menu addTarget: self
            action: @selector(buttonPressed:)
         forControlEvents: UIControlEventValueChanged];
   [[self navigationItem] setTitleView: menu];
   [menu release];

   // Selected piece view
   SelectedPieceView *spv =
      [[SelectedPieceView alloc] initWithFrame:
                                    CGRectMake(40.0f, 330.0f, 240.0f, 80.0f)];
   [contentView addSubview: spv];
   [spv release];

   // Setup board view
   boardView = [[SetupBoardView alloc] initWithController: self
                                                      fen: fen
                                                    phase: PHASE_EDIT_BOARD];
   [contentView addSubview: boardView];
   [boardView setSelectedPieceView: spv];
   [boardView release];

   [contentView release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)buttonPressed:(id)sender {
   switch([sender selectedSegmentIndex]) {
   case 0:
      [boardView clear];
      break;
   case 1:
      [boardViewController editPositionCancelPressed];
      break;
   case 2:
      SideToMoveController *stmc = [[SideToMoveController alloc]
                                      initWithFen: [boardView fen]];
      [[self navigationController] pushViewController: stmc animated: YES];
      [stmc release];
      break;
   }
}


- (void)disableDoneButton {
   [menu setEnabled: NO forSegmentAtIndex: 2];
}


- (void)enableDoneButton {
   [menu setEnabled: YES forSegmentAtIndex: 2];
}


- (void)dealloc {
   [fen release];
   [super dealloc];
}


@end
