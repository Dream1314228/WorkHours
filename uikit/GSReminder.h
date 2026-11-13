#import <Foundation/Foundation.h>

@interface GSReminder : NSObject
+ (void)syncFromSettings;
+ (void)requestAndSync;
@end
