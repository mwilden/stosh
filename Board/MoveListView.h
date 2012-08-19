@class GameController;

@interface MoveListView : UITextView {
   GameController *gameController;
   CGPoint touchStartPoint;
   BOOL horizontalSwipe;
}

@property (nonatomic,assign) GameController *gameController;

@end
