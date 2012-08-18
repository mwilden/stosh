#import <UIKit/UIKit.h>

@class BoardViewController;
@class SetupBoardView;

@interface SetupViewController : UIViewController {
   BoardViewController *boardViewController;
   SetupBoardView *boardView;
   UISegmentedControl *menu;
   NSString *fen;
}

@property (nonatomic, readonly) BoardViewController *boardViewController;

- (id)initWithBoardViewController:(BoardViewController *)bvc
                              fen:(NSString *)aFen;
- (void)buttonPressed:(id)sender;
- (void)disableDoneButton;
- (void)enableDoneButton;

@end
