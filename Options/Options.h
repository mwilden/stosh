@interface Options : NSObject {
   UIColor *darkSquareColor, *lightSquareColor, *highlightColor;
   UIImage *darkSquareImage, *lightSquareImage;
}

@property (nonatomic, readonly) UIColor *darkSquareColor;
@property (nonatomic, readonly) UIColor *lightSquareColor;
@property (nonatomic, readonly) UIColor *highlightColor;
@property (nonatomic, readonly) UIImage *darkSquareImage;
@property (nonatomic, readonly) UIImage *lightSquareImage;

+ (Options *)sharedOptions;

- (void)updateColors;

@end
