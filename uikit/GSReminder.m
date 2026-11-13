#import "GSReminder.h"
#import "GSStore.h"
#import <UserNotifications/UserNotifications.h>

@interface GSReminder ()
+ (void)scheduleWithSettings:(NSDictionary *)s;
+ (NSArray<NSString *> *)allIdentifiers;
@end

@implementation GSReminder
+ (void)syncFromSettings {
    NSDictionary *s = [GSStore shared].settings;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    if (![s[@"reminderEnabled"] boolValue]) {
        [center removePendingNotificationRequestsWithIdentifiers:[self allIdentifiers]];
        return;
    }
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
            [center removePendingNotificationRequestsWithIdentifiers:[self allIdentifiers]];
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
+ (NSArray<NSString *> *)allIdentifiers {
    NSMutableArray *ids = [NSMutableArray arrayWithObject:@"GSRecordDailyReminder"];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *now = [NSDate date];
    for (NSInteger i = 0; i < 14; i++) {
        NSDate *day = [cal dateByAddingUnit:NSCalendarUnitDay value:i toDate:now options:0];
        [ids addObject:[NSString stringWithFormat:@"GSRecordDailyReminder-%@", GSKeyFromDate(day)]];
    }
    return ids;
}
+ (void)requestAndSync {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError *error) {
        if (granted) [self syncFromSettings];
    }];
}
+ (void)scheduleWithSettings:(NSDictionary *)s {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *now = [NSDate date];
    NSInteger hour = MAX(0, MIN(23, [s[@"reminderHour"] integerValue]));
    NSInteger minute = MAX(0, MIN(59, [s[@"reminderMinute"] integerValue]));
    [center removePendingNotificationRequestsWithIdentifiers:[self allIdentifiers]];
    for (NSInteger i = 0; i < 14; i++) {
        NSDate *day = [cal dateByAddingUnit:NSCalendarUnitDay value:i toDate:now options:0];
        NSString *key = GSKeyFromDate(day);
        if ([[GSStore shared] recordForDate:key]) continue;
        NSDateComponents *c = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:day];
        c.hour = hour; c.minute = minute;
        NSDate *fireDate = [cal dateFromComponents:c];
        if (!fireDate || [fireDate compare:now] != NSOrderedDescending) continue;
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = @"工时记录";
        content.body = [NSString stringWithFormat:@"%ld月%ld日还没有记录工时，花十秒补一笔。", (long)c.month, (long)c.day];
        content.sound = [UNNotificationSound defaultSound];
        UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:c repeats:NO];
        NSString *identifier = [NSString stringWithFormat:@"GSRecordDailyReminder-%@", key];
        [center addNotificationRequest:[UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger] withCompletionHandler:nil];
    }
}
@end
