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

#import "EngineController.h"
#import "GameController.h"

#include "../Engine/iphone.h"

EngineController *GlobalEngineController; // HACK

@implementation EngineController

@synthesize engineIsThinking, engineThreadIsRunning;

- (id)initWithGameController:(GameController *)gc {
   if (self = [super init]) {
      commandQueue = [[Queue alloc] init];
      gameController = gc;

      // Initialize locks and conditions
      pthread_mutex_init(&WaitConditionLock, NULL);
      pthread_cond_init(&WaitCondition, NULL);

      // Start engine thread
      NSThread *thread =
         [[NSThread alloc] initWithTarget: self
                                 selector: @selector(startEngine:)
                                   object: nil];
      [thread setStackSize: 0x100000];
      [thread start];
      [thread release];

      ignoreBestmove = NO;
      engineIsThinking = NO;
   }
   GlobalEngineController = self;
   return self;
}

- (void)startEngine:(id)anObject {
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

   engineThreadIsRunning = YES;
   engineThreadShouldStop = NO;

   engine_init();

   while (!engineThreadShouldStop) {
      pthread_mutex_lock(&WaitConditionLock);
      if ([commandQueue isEmpty])
         pthread_cond_wait(&WaitCondition, &WaitConditionLock);
      pthread_mutex_unlock(&WaitConditionLock);
      while (![commandQueue isEmpty]) {
         NSString *command = [commandQueue pop];
         if ([command hasPrefix: @"go"])
            engineIsThinking = YES;
         command_to_engine([command UTF8String]);
         engineIsThinking = NO;
      }
   }

   NSLog(@"engine is quitting");
   [pool release];
   engineThreadIsRunning = NO;
}

- (void)sendCommand:(NSString *)command {
   NSLog(@"sending %@", command);
   [commandQueue push: command];
}


- (void)abortSearch {
   NSLog(@"aborting search");
   [self sendCommand: @"stop"];
}


- (void)commitCommands {
   NSLog(@"commiting commands");
   pthread_mutex_lock(&WaitConditionLock);
   pthread_cond_signal(&WaitCondition);
   pthread_mutex_unlock(&WaitConditionLock);
}


- (BOOL)commandIsWaiting {
   return ![commandQueue isEmpty];
}


- (NSString *)getCommand {
   assert(![commandQueue isEmpty]);
   return [commandQueue pop];
}


- (void)sendPV:(NSString *)pv {
   [gameController displayPV: pv];
}


- (void)sendSearchStats:(NSString *)searchStats {
   [gameController displaySearchStats: searchStats];
}


- (void)sendBestMove:(NSString *)bestMove ponderMove:(NSString *)ponderMove {
   NSLog(@"received best move: %@ ponder move: %@", bestMove, ponderMove);
   if (!ignoreBestmove)
      [gameController performSelectorOnMainThread: @selector(engineMadeMove:)
                                       withObject: [NSArray arrayWithObjects:
                                                               bestMove, ponderMove, nil]
                                    waitUntilDone: NO];
   else {
      NSLog(@"ignoring best move");
      ignoreBestmove = NO;
   }
}


- (void)ponderhit {
   NSLog(@"Ponder hit");
   [self sendCommand: @"ponderhit"];
}


- (void)pondermiss {
   NSLog(@"Ponder miss");
   ignoreBestmove = YES;
   [self sendCommand: @"stop"];
}


- (void)dealloc {
   NSLog(@"EngineController dealloc");
   [commandQueue release];
   pthread_cond_destroy(&WaitCondition);
   pthread_mutex_destroy(&WaitConditionLock);
   [super dealloc];
}


- (void)quit {
   ignoreBestmove = YES;
   engineThreadShouldStop = YES;
   [self sendCommand: @"quit"];
   [self commitCommands];
   NSLog(@"waiting for engine thread to exit...");
   while (![NSThread isMultiThreaded]);
   NSLog(@"engine thread exited");
}


@end
