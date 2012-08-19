#import "AboutController.h"

@implementation AboutController

- (id)init {
   if (self = [super init]) {
      [self setContentSizeForViewInPopover: CGSizeMake(500.0f, 400.0f)];
   }
   return self;
}

- (void)loadView {
   [super loadView];
#if defined(SANDBOX)
   NSString *path = [[NSBundle mainBundle] pathForResource: @"about"
                                                    ofType: @"html"];
#else
   NSString *path = [[NSBundle mainBundle] pathForResource: @"about-abaia"
                                                    ofType: @"html"];
#endif
   NSURL *url = [[NSURL alloc] initFileURLWithPath: path];
   NSURLRequest *req = [NSURLRequest requestWithURL: url];
   UIWebView *webView =
      [[UIWebView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]];
   [webView setScalesPageToFit: YES];
   [webView loadRequest: req];
   [self setView: webView];
   [webView release];
   [url release];
}


- (void)didReceiveMemoryWarning {
   [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
   // Release anything that's not essential, such as cached data
}


- (void)dealloc {
   [super dealloc];
}


@end
