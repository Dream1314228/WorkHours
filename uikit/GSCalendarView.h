#import <UIKit/UIKit.h>
#import "GSComponents.h"
@interface GSCalendarView : GSCardView
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, assign) NSInteger month;
@property (nonatomic, copy) NSString *selectedDate;
@property (nonatomic, copy) void (^onSelect)(NSString *date);
- (void)reload;
@end
