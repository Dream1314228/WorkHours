#import <Foundation/Foundation.h>
#import "GSCommon.h"

NS_ASSUME_NONNULL_BEGIN
@interface GSStore : NSObject
@property (nonatomic, strong, readonly) NSMutableDictionary *data;
+ (instancetype)shared;
- (void)load;
- (void)save;
- (NSMutableDictionary *)settings;
- (NSArray *)projects;
- (NSArray *)classes;
- (NSDictionary *)projectWithId:(NSString *)pid;
- (NSDictionary *)classWithId:(NSString *)cid;
- (NSDictionary *)recordForDate:(NSString *)date;
- (void)setRecord:(NSDictionary *)rec forDate:(NSString *)date;
- (void)removeRecordForDate:(NSString *)date;
- (NSString *)planForDate:(NSString *)date;
- (void)setPlan:(NSString *)classId forDate:(NSString *)date;
- (double)rateForProject:(NSString *)pid type:(NSString *)type;
- (double)dayPay:(NSDictionary *)rec;
- (double)dayHours:(NSDictionary *)rec;
- (double)annualLeaveTotalDays;
- (double)annualLeaveUsedDaysForYear:(NSInteger)year;
- (double)annualLeaveRemainingDaysForYear:(NSInteger)year;
- (NSString *)daySummary:(NSDictionary *)rec;
- (NSDictionary *)periodRange:(NSInteger)year month:(NSInteger)month;
- (NSDictionary *)monthStats:(NSInteger)year month:(NSInteger)month usePeriod:(BOOL)usePeriod;
- (NSDictionary *)yearStats:(NSInteger)year;
- (NSArray<NSString *> *)dailyKeysForYear:(NSInteger)year month:(NSInteger)month;
- (NSArray *)extrasForKind:(NSString *)kind year:(NSInteger)year month:(NSInteger)month;
- (void)addExtra:(NSString *)kind year:(NSInteger)year month:(NSInteger)month name:(NSString *)name money:(double)money note:(NSString *)note;
- (void)deleteExtra:(NSString *)kind year:(NSInteger)year month:(NSInteger)month index:(NSInteger)index;
- (void)importLastMonthToKind:(NSString *)kind year:(NSInteger)year month:(NSInteger)month;
- (void)importLastMonthBothToYear:(NSInteger)year month:(NSInteger)month;
- (NSDictionary *)backupDictionary;
- (BOOL)importBackupData:(NSDictionary *)raw;
- (void)autoCarry;
- (NSDictionary *)defaultWorkForClass:(NSString *)cid;
- (void)setClassDefault:(NSString *)cid key:(NSString *)key value:(double)value;
- (void)ensureAutoAllowance:(NSMutableDictionary *)rec;
- (NSString *)allowanceNameForClass:(NSString *)cid;
- (void)clearAllRecords;
- (NSInteger)removeAutoAllowanceNamed:(NSString *)name;
- (NSString *)reportTextForYear:(NSInteger)year month:(NSInteger)month;
@end
NS_ASSUME_NONNULL_END
