#import "Options.h"


@implementation Options

@synthesize darkSquareColor, lightSquareColor, highlightColor;
@synthesize darkSquareImage, lightSquareImage;

- (id)init {
   if (self = [super init]) {
      darkSquareColor = lightSquareColor = highlightColor = nil;
      [self updateColors];
   }
   return self;
}


- (void)updateColors {
   [darkSquareColor release];
   [lightSquareColor release];
   [highlightColor release];
   [darkSquareImage release]; darkSquareImage = nil;
   [lightSquareImage release]; lightSquareImage = nil;
  darkSquareColor = [[UIColor colorWithRed: 0.20 green: 0.40 blue: 0.70
                                     alpha: 1.0]
                       retain];
  lightSquareColor = [[UIColor colorWithRed: 0.69 green: 0.78 blue: 1.0
                                      alpha: 1.0]
                        retain];
  highlightColor = [[UIColor purpleColor] retain];
}

- (void)dealloc {
   [darkSquareImage release];
   [lightSquareImage release];
   [super dealloc];
}


+ (Options *)sharedOptions {
   static Options *o = nil;
   if (o == nil) {
      o = [[Options alloc] init];
   }
   return o;
}

@end
