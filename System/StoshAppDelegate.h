#import <UIKit/UIKit.h>

@class BoardViewController;
@class GameController;

@interface StoshAppDelegate : NSObject <UIApplicationDelegate> {
   UIWindow *window;
   BoardViewController *viewController;
   GameController *gameController;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, readonly) BoardViewController *viewController;
@property (nonatomic, readonly) GameController *gameController;

- (void)backgroundInit:(id)anObject;
- (void)backgroundInitFinished:(id)anObject;

@end

