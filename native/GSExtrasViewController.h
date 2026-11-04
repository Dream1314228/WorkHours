#import <UIKit/UIKit.h>
@interface GSExtrasViewController : UIViewController
- (instancetype)initWithYear:(NSInteger)year month:(NSInteger)month;
@property (nonatomic, copy) void (^onChanged)(void);
@end
