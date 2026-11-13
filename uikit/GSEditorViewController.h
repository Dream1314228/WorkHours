#import <UIKit/UIKit.h>
@interface GSEditorViewController : UIViewController
- (instancetype)initWithDate:(NSString *)date;
@property (nonatomic, copy) void (^onSaved)(void);
@end
