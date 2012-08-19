@class SetupBoardView;

@interface SideToMoveController : UIViewController {
   SetupBoardView *boardView;
   UISegmentedControl *segmentedControl;
   NSString *fen;
}

- (id)initWithFen:(NSString *)aFen;
- (void)donePressed;

@end
