#import <UIKit/UIKit.h>

@class SetupBoardView;

@interface EpSquareController : UIViewController {
   SetupBoardView *boardView;
   NSString *fen;
}

- (id)initWithFen:(NSString *)aFen;
- (void)donePressed;

@end
