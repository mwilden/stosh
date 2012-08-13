#import <UIKit/UIKit.h>


@interface SelectedSquareView : UIView {
   BOOL hidden;
   float size;
}

- (void)hide;
- (void)moveToPoint:(CGPoint)point;

@end
