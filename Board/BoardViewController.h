@class BoardView;
@class GameController;
@class MoveListView;

@interface BoardViewController : UIViewController <UIActionSheetDelegate> {
   UIView *contentView;
   BoardView *boardView;
   MoveListView *moveListView;
   GameController *gameController;
   UINavigationController *navigationController;
   UIActionSheet *gameMenu, *newGameMenu, *moveMenu;
   UIBarButtonItem *gameButton;
   UIPopoverController *saveMenu, *loadMenu;
   UIPopoverController *popoverMenu;
}

@property (nonatomic, readonly) BoardView *boardView;
@property (nonatomic, readonly) MoveListView *moveListView;
@property (nonatomic, assign) GameController *gameController;

- (void)toolbarButtonPressed:(id)sender;
- (void)editPosition;
- (void)editPositionCancelPressed;
- (void)editPositionDonePressed:(NSString *)fen;

@end
