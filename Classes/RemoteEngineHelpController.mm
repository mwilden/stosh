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

#import "RemoteEngineHelpController.h"

@implementation RemoteEngineHelpController

- (id)init {
   if (self = [super init])
      [self setContentSizeForViewInPopover: CGSizeMake(500.0f, 400.0f)];
   return self;
}


- (void)loadView {
   [super loadView];

   NSURL *url = [[NSURL alloc] initFileURLWithPath:
                                  [[NSBundle mainBundle]
                                     pathForResource: @"remote-engine-help"
                                              ofType: @"html"]];
   NSURLRequest *req = [NSURLRequest requestWithURL: url];
   UIWebView *webView =
      [[UIWebView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]];
   [webView setScalesPageToFit: YES];
   [webView loadRequest: req];
   [self setView: webView];
   [webView release];
   [url release];
}

@end
