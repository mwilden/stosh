#import <Foundation/Foundation.h>


@interface Queue : NSObject {
   NSMutableArray *contents;
}

- (BOOL)isEmpty;
- (int)size;
- (id)front;
- (id)back;
- (void)push:(id)anObject;
- (id)pop;

@end
