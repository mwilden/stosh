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

#import "GameController.h"
#import "RemoteEngineController.h"

// Apple, in their infinite wisdom, seem to have simply removed NSStream's
// getStreamsToHost:port:inputStream:outputStream in SDK 3.0, so we are forced
// to add our own crude replacement below. Thank you, Apple.

@interface NSStream (StockfishAddon)
+ (void)getStreamsToHostWithName:(NSString *)name
                            port:(int)port
                     inputStream:(NSInputStream **)istreamptr
                    outputStream:(NSOutputStream **)ostreamptr;
@end

@implementation NSStream (StockfishAddon)
+ (void)getStreamsToHostWithName:(NSString *)hostName
                            port:(int)port
                     inputStream:(NSInputStream **)istreamptr
                    outputStream:(NSOutputStream **)ostreamptr
{
   CFReadStreamRef readStream;
   CFWriteStreamRef writeStream;

   assert(hostName != nil);
   assert(port > 0 && port < 65536);
   assert(istreamptr != NULL && ostreamptr != NULL);

   readStream = NULL, writeStream = NULL;
   CFStreamCreatePairWithSocketToHost(NULL,
                                      (CFStringRef) hostName, port,
                                      &readStream, &writeStream);
   *istreamptr  = [NSMakeCollectable(readStream) autorelease];
   *ostreamptr = [NSMakeCollectable(writeStream) autorelease];
}
@end


@implementation RemoteEngineController

@synthesize isConnected;

static bool ErrorAlertIsDisplayed = NO;
static bool SuccessAlertIsDisplayed = NO;

- (id)initWithGameController:(GameController *)gc {
   if(self = [super init]) {
      gameController = gc;
      isConnected = NO;
   }
   return self;
}


- (void)connectToServer:(NSString *)serverName port:(int)portNumber {
   NSURL *site = [NSURL URLWithString: serverName];
   if (!site) {
      NSLog(@"Error 1");
      return;
   }
   NSLog(@"host name: %@", [site host]);
   [NSStream getStreamsToHostWithName: serverName
                                 port: portNumber
                          inputStream: &istream
                         outputStream: &ostream];

   if (istream == nil)
      NSLog(@"Error 2");

   [istream retain];
   [istream setDelegate: self];
   [istream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                      forMode: NSDefaultRunLoopMode];
   [istream open];

   [ostream retain];
   [ostream setDelegate: self];
   [ostream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                      forMode: NSDefaultRunLoopMode];
   [ostream open];

   if (ostream == nil)
      NSLog(@"Error 3");

   //isConnected = YES;
}


- (void)disconnect {
   [self sendToServer: @"bye\n"];
   isConnected = NO;
}


- (void)sendToServer:(NSString *)string {
   if (isConnected) {
      const char *str = [string UTF8String];
      NSLog(@"sending to server: %s", str);
      [ostream write: (const uint8_t *)str maxLength: strlen(str)];
   }
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
   ErrorAlertIsDisplayed = NO;
   if (SuccessAlertIsDisplayed && isConnected)
      [self sendToServer: [[gameController game] remoteEngineGameString]];
   SuccessAlertIsDisplayed = NO;
}


- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
   if (eventCode == NSStreamEventHasBytesAvailable) {
      NSMutableData *data = [[NSMutableData alloc] init];
      uint8_t buf[1024];
      unsigned len = 0;
      len = [(NSInputStream *)stream read: buf maxLength: 1024];
      if (len) {
         [data appendBytes: (const void *)buf length: len];
         int bytesRead;
         bytesRead += len;
      }
      else {
         NSLog(@"no data");
         return;
      }

      NSString *str =
         [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
      NSLog(@"%@", str);
      NSArray *lines = [str componentsSeparatedByString: @"\n"];
      for (id line in lines) {
         if (isdigit([line UTF8String][0]))
            // Output is a PV -- display it!
            [gameController displayPV: line];
         else if ([line UTF8String][0] == 'b') {
            // Remote engine made a move!
            [gameController
               engineMadeMove:
                  [[line substringFromIndex: 2] componentsSeparatedByString: @" "]];
         }
      }
      [str release];
      [data release];
   }
   else if (eventCode == NSStreamEventOpenCompleted) {
      if (!SuccessAlertIsDisplayed) {
         SuccessAlertIsDisplayed = YES;
         [[[[UIAlertView alloc] initWithTitle: @"Connected"
                                      message: @"Connected successfully to remote chess server."
                                     delegate: self
                            cancelButtonTitle: nil
                            otherButtonTitles: @"OK", nil]
             autorelease]
            show];
      }
      isConnected = YES;
      NSLog(@"open completed");
   }
   else if (eventCode == NSStreamEventErrorOccurred) {
      if (!ErrorAlertIsDisplayed) {
         ErrorAlertIsDisplayed = YES;
         [[[[UIAlertView alloc] initWithTitle: @"Error:"
                                      message: @"Failed to connect to server. Please make sure the server is running, and that the IP and port number are correct."
                                     delegate: self
                            cancelButtonTitle: nil
                            otherButtonTitles: @"OK", nil]
             autorelease]
            show];
      }
      NSLog(@"error occured");
      isConnected = NO;
   }
   else if (eventCode == NSStreamEventEndEncountered) {
      NSLog(@"end encountered");
      isConnected = NO;
   }
}


- (void)dealloc {
   [self disconnect];
   [istream release];
   [ostream release];
   [super dealloc];
}


@end
