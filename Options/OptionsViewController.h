@class BoardViewController;

@interface OptionsViewController : UITableViewController {
   BoardViewController *boardViewController;
}

@property (nonatomic, readonly) BoardViewController *boardViewController;

- (id)initWithBoardViewController:(BoardViewController *)bvc;

@end
