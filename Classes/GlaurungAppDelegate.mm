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
	
	[viewController release];
	[gameController release];
	[[Options sharedOptions] release];
	[window release];
}


- (void)backgroundInit:(id)anObject {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	gameController =
	[[GameController alloc] initWithBoardView: [viewController boardView]
								 moveListView: [viewController moveListView]
							  searchStatsView: [viewController searchStatsView]];
	
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
	[gameController showPiecesAnimate: YES];
	[viewController stopActivityIndicator];
	
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
