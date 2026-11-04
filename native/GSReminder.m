#import "GSReminder.h"
#import "GSStore.h"
#import <UserNotifications/UserNotifications.h>

@interface GSReminder ()
+ (void)scheduleWithSettings:(NSDictionary *)s;
@end

@implementation GSReminder
+ (void)syncFromSettings {
    NSDictionary *s = [GSStore shared].settings;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    if (![s[@"reminderEnabled"] boolValue]) {
        [center removePendingNotificationRequestsWithIdentifiers:@[@"GSRecordDailyReminder"]];
        return;
    }
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
            [center removePendingNotificationRequestsWithIdentifiers:@[@"GSRecordDailyReminder"]];
            return;
        }
        if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError *error) {
                if (granted) [self scheduleWithSettings:s];
            }];
        } else {
            [self scheduleWithSettings:s];
        }
    }];
}
+ (void)requestAndSync {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError *error) {
        if (granted) [self syncFromSettings];
    }];
}
+ (void)scheduleWithSettings:(NSDictionary *)s {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[@"GSRecordDailyReminder"]];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = @"工时记录";
    content.body = @"今天还没有补记工时的话，花十秒记一笔。";
    content.sound = [UNNotificationSound defaultSound];
    NSDateComponents *c = [NSDateComponents new];
    c.hour = MAX(0, MIN(23, [s[@"reminderHour"] integerValue]));
    c.minute = MAX(0, MIN(59, [s[@"reminderMinute"] integerValue]));
    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:c repeats:YES];
    UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:@"GSRecordDailyReminder" content:content trigger:trigger];
    [center addNotificationRequest:req withCompletionHandler:nil];
}
@end
