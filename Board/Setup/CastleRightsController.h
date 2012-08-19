@class SetupBoardView;

@interface CastleRightsController : UIViewController {
   SetupBoardView *boardView;
   UISwitch *wOOOswitch, *wOOswitch, *bOOOswitch, *bOOswitch;
   NSString *fen;
}

- (id)initWithFen:(NSString *)aFen;
- (void)donePressed;


@end
