#import <UIKit/UIKit.h>

@interface GSBatchViewController : UIViewController
- (instancetype)initWithStartDate:(NSString *)start endDate:(NSString *)end;
@property (nonatomic, copy) void (^onSaved)(NSInteger count);
@end
