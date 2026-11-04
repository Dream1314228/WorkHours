#import <UIKit/UIKit.h>

@interface GSProjectEditViewController : UIViewController
- (instancetype)initWithProject:(NSDictionary *)project index:(NSInteger)index;
@property (nonatomic, copy) void (^onSaved)(void);
@end
