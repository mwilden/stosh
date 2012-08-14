#import <UIKit/UIKit.h>

#import "BoardView.h"

@class GameController;
@class MoveListView;

@interface BoardViewController : UIViewController <UIActionSheetDelegate> {
   UIView *contentView;
   BoardView *boardView;
   MoveListView *moveListView;
   GameController *gameController;
   UINavigationController *navigationController;
   UIActivityIndicatorView *activityIndicator;
   UIActionSheet *gameMenu, *newGameMenu, *moveMenu;
   UIBarButtonItem *gameButton, *optionsButton;
   UIPopoverController *optionsMenu, *saveMenu, *loadMenu;
   UIPopoverController *popoverMenu;
}

@property (nonatomic, readonly) BoardView *boardView;
@property (nonatomic, readonly) MoveListView *moveListView;
@property (nonatomic, assign) GameController *gameController;

- (void)toolbarButtonPressed:(id)sender;
- (void)showOptionsMenu;
- (void)optionsMenuDonePressed;
- (void)editPosition;
- (void)editPositionCancelPressed;
- (void)editPositionDonePressed:(NSString *)fen;
- (void)stopActivityIndicator;

@end
