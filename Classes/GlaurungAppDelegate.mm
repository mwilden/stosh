#import "TargetConditionals.h"

#import "GlaurungAppDelegate.h"
#import "Options.h"
#import "PGN.h"

#include <sys/stat.h>

#include "../Chess/bitboard.h"
#include "../Chess/direction.h"
#include "../Chess/mersenne.h"
#include "../Chess/movepick.h"
#include "../Chess/position.h"

using namespace Chess;

@implementation GlaurungAppDelegate

@synthesize window, viewController, gameController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
	NSLog(@"%@", PGN_DIRECTORY);
	
#if defined(TARGET_OS_IPHONE)
	if (!Sandbox)
		mkdir("/var/mobile/Library/abaia", 0755);
#endif
	// Ccommenting this line out seems to fix the "white screen" issue when using the simulator.
	// It was originally uncommented.
	// window = [[UIWindow alloc] initWithFrame: [[UIScreen mainScreen] bounds]];
	
	viewController = [[BoardViewController alloc] init];
	[viewController loadView];
	[window addSubview: [viewController view]];
	
	[window makeKeyAndVisible];
	
	[[UIApplication sharedApplication] setIdleTimerDisabled: YES];
	
	[self performSelectorInBackground: @selector(backgroundInit:)
						   withObject: nil];
}


- (void)applicationWillTerminate:(UIApplication *)application {
	NSLog(@"GlaurungAppDelegate applicationWillTerminate:");
	
	// Save the current game so we can recover it the next
	// time the program starts up:
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [[gameController game] pgnString]
				 forKey: @"lastGame"];
	[defaults setBool: [gameController rotated]
			   forKey: @"rotateBoard"];
	[defaults synchronize];
}


- (void)backgroundInit:(id)anObject {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	gameController =
	[[GameController alloc] initWithBoardView: [viewController boardView]
								 moveListView: [viewController moveListView]];
	
	/* Chess init */
	init_mersenne();
	init_direction_table();
	init_bitboards();
	Position::init_zobrist();
	Position::init_piece_square_tables();
	MovePicker::init_phase_table();
	
	[gameController loadPieceImages];
	[self performSelectorOnMainThread: @selector(backgroundInitFinished:)
						   withObject: nil
						waitUntilDone: NO];
	
	[pool release];
}


- (void)backgroundInitFinished:(id)anObject {
	[gameController showPieces];
	
	[viewController setGameController: gameController];
	[[viewController boardView] setGameController: gameController];
	[[viewController moveListView] setGameController: gameController];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *lastGamePGNString = [defaults objectForKey: @"lastGame"];
	if (lastGamePGNString)
		[gameController gameFromPGNString: lastGamePGNString];
	else
		[gameController
         gameFromFEN: @"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"];
	
	if ([defaults objectForKey: @"rotateBoard"])
		[gameController rotateBoard: [defaults boolForKey: @"rotateBoard"]];
}


- (void)dealloc {
	NSLog(@"GlaurungAppDelegate dealloc");
	[super dealloc];
}

@end
