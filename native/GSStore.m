#import "GSStore.h"
static GSStore *_shared;
@implementation GSStore
+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ _shared = [[GSStore alloc] init]; });
    return _shared;
}
- (instancetype)init {
    self = [super init];
    if (self) { [self load]; }
    return self;
}
- (NSString *)filePath {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [dir stringByAppendingPathComponent:@"gsjilu.json"];
}
- (NSMutableDictionary *)defaults {
    NSMutableDictionary *settings = [@{
        @"period": @26, @"customPeriods": [NSMutableArray array], @"weekStart": @1, @"payday": @0,
        @"nightMode": @YES, @"autoBonus": @YES, @"recordMode": @"hour", @"classDisplay": @"icon", @"annualLeaveDays": @5, @"theme": @"blue", @"headerRadius": @24,
        @"defaultWork": [@{@"zb":@8, @"jb":@2, @"zm":@10, @"jj":@10} mutableCopy],
        @"dayAllowance": @10, @"nightAllowance": @20, @"reminderEnabled": @NO, @"reminderHour": @21, @"reminderMinute": @0,
        @"classDefaults": [@{
            @"1": [@{@"zb":@8, @"jb":@2, @"zm":@10, @"jj":@10, @"rjgz":@0} mutableCopy],
            @"4": [@{@"zb":@8, @"jb":@4, @"zm":@12, @"jj":@12, @"rjgz":@0} mutableCopy]
        } mutableCopy],
        @"projectId": @"default", @"currentClass": @"1", @"autoCarryMonth": @""
    } mutableCopy];
    NSArray *projects = @[
        [@{@"id":@"default", @"name":@"默认项目", @"mode":@"dxjs", @"base":@2230,
           @"rates":@{@"zb":@12.82, @"jb":@19.23, @"zm":@25.64, @"jj":@38.46}} mutableCopy],
        [@{@"id":@"2", @"name":@"祥发模具", @"mode":@"gddx", @"base":@3300,
           @"rates":@{@"zb":@18.97, @"jb":@18.96, @"zm":@25.28, @"jj":@37.92}} mutableCopy]
    ];
    NSArray *classes = @[
        [@{@"id":@"1", @"name":@"白班", @"color":@"#FCB819"} mutableCopy],
        [@{@"id":@"2", @"name":@"早班", @"color":@"#33A0FF"} mutableCopy],
        [@{@"id":@"3", @"name":@"中班", @"color":@"#FF9900"} mutableCopy],
        [@{@"id":@"4", @"name":@"晚班", @"color":@"#224799"} mutableCopy]
    ];
    return [@{
        @"v": @2, @"settings": settings, @"projects": [projects mutableCopy], @"classes": [classes mutableCopy],
        @"records": [NSMutableDictionary dictionary], @"plans": [NSMutableDictionary dictionary],
        @"bonuses": [NSMutableDictionary dictionary], @"deductions": [NSMutableDictionary dictionary]
    } mutableCopy];
}
- (void)sanitizeData {
    if (!_data) return;
    NSMutableDictionary *settings = _data[@"settings"];
    if (![settings isKindOfClass:[NSMutableDictionary class]]) { settings = [NSMutableDictionary dictionary]; _data[@"settings"] = settings; }
    if (![settings[@"period"] isKindOfClass:[NSNumber class]]) settings[@"period"] = @26;
    NSInteger pday = [settings[@"period"] integerValue];
    if (pday < 1 || pday > 29) settings[@"period"] = @26;
    if (![settings[@"weekStart"] isKindOfClass:[NSNumber class]]) settings[@"weekStart"] = @1;
    if (![settings[@"theme"] isKindOfClass:[NSString class]]) settings[@"theme"] = @"blue";
    GSSetThemeKey(settings[@"theme"]);
    if (![settings[@"headerRadius"] isKindOfClass:[NSNumber class]]) settings[@"headerRadius"] = @24;
    double hr = [settings[@"headerRadius"] doubleValue];
    if (hr < 0) hr = 0; if (hr > 40) hr = 40;
    settings[@"headerRadius"] = @(hr);
    if (![settings[@"payday"] isKindOfClass:[NSNumber class]]) settings[@"payday"] = @0;
    NSInteger payday = [settings[@"payday"] integerValue];
    if (payday < 0 || payday > 31) settings[@"payday"] = @0;
    if (![settings[@"nightMode"] isKindOfClass:[NSNumber class]]) settings[@"nightMode"] = @YES;
    if (![settings[@"autoBonus"] isKindOfClass:[NSNumber class]]) settings[@"autoBonus"] = @YES;
    if (![settings[@"annualLeaveDays"] isKindOfClass:[NSNumber class]]) settings[@"annualLeaveDays"] = @5;
    if (![settings[@"dayAllowance"] isKindOfClass:[NSNumber class]]) settings[@"dayAllowance"] = @10;
    if (![settings[@"nightAllowance"] isKindOfClass:[NSNumber class]]) settings[@"nightAllowance"] = @20;
    if (![settings[@"reminderEnabled"] isKindOfClass:[NSNumber class]]) settings[@"reminderEnabled"] = @NO;
    if (![settings[@"reminderHour"] isKindOfClass:[NSNumber class]]) settings[@"reminderHour"] = @21;
    if (![settings[@"reminderMinute"] isKindOfClass:[NSNumber class]]) settings[@"reminderMinute"] = @0;
    NSInteger rh = [settings[@"reminderHour"] integerValue]; if (rh < 0 || rh > 23) settings[@"reminderHour"] = @21;
    NSInteger rm = [settings[@"reminderMinute"] integerValue]; if (rm < 0 || rm > 59) settings[@"reminderMinute"] = @0;
    if (![settings[@"projectId"] isKindOfClass:[NSString class]]) settings[@"projectId"] = @"default";
    if (![settings[@"currentClass"] isKindOfClass:[NSString class]]) settings[@"currentClass"] = @"1";
    if (![settings[@"customPeriods"] isKindOfClass:[NSMutableArray class]]) settings[@"customPeriods"] = [NSMutableArray arrayWithArray:([settings[@"customPeriods"] isKindOfClass:[NSArray class]] ? settings[@"customPeriods"] : @[])];
    NSMutableArray *cleanPeriods = [NSMutableArray array];
    for (id p in settings[@"customPeriods"]) {
        if (![p isKindOfClass:[NSDictionary class]] || ![p[@"start"] isKindOfClass:[NSString class]] || ![p[@"end"] isKindOfClass:[NSString class]]) continue;
        [cleanPeriods addObject:@{@"start":p[@"start"], @"end":p[@"end"]}];
    }
    settings[@"customPeriods"] = cleanPeriods;
    if (![settings[@"classDefaults"] isKindOfClass:[NSMutableDictionary class]]) settings[@"classDefaults"] = [NSMutableDictionary dictionaryWithDictionary:([settings[@"classDefaults"] isKindOfClass:[NSDictionary class]] ? settings[@"classDefaults"] : @{})];
    if (![settings[@"defaultWork"] isKindOfClass:[NSDictionary class]]) settings[@"defaultWork"] = [@{@"zb":@8, @"jb":@2, @"zm":@10, @"jj":@10} mutableCopy];
    NSMutableDictionary *cd = settings[@"classDefaults"];
    for (NSString *ck in [cd.allKeys copy]) {
        id cv = cd[ck];
        if (![cv isKindOfClass:[NSDictionary class]]) { [cd removeObjectForKey:ck]; continue; }
        NSMutableDictionary *cv2 = [cv mutableCopy];
        for (NSString *wk in @[@"zb", @"jb", @"zm", @"jj", @"rjgz"]) if (![cv2[wk] isKindOfClass:[NSNumber class]]) cv2[wk] = @0;
        cd[ck] = cv2;
    }
    NSArray *projects = _data[@"projects"];
    if ([projects isKindOfClass:[NSArray class]]) {
        NSMutableArray *clean = [NSMutableArray array];
        for (id p in projects) {
            if (![p isKindOfClass:[NSDictionary class]]) continue;
            NSMutableDictionary *pp = [p mutableCopy];
            if (![pp[@"id"] isKindOfClass:[NSString class]]) pp[@"id"] = [NSUUID UUID].UUIDString;
            if (![pp[@"name"] isKindOfClass:[NSString class]]) pp[@"name"] = @"项目";
            if (![pp[@"rates"] isKindOfClass:[NSDictionary class]]) pp[@"rates"] = [NSMutableDictionary dictionary];
            NSMutableDictionary *rates = [pp[@"rates"] mutableCopy];
            for (NSString *rk in @[@"zb", @"jb", @"zm", @"jj"]) if (![rates[rk] isKindOfClass:[NSNumber class]]) rates[rk] = @0;
            pp[@"rates"] = rates;
            if (![pp[@"base"] isKindOfClass:[NSNumber class]]) pp[@"base"] = @0;
            [clean addObject:pp];
        }
        _data[@"projects"] = clean;
    }
    NSMutableDictionary *records = _data[@"records"];
    if (![records isKindOfClass:[NSMutableDictionary class]]) {
        records = [NSMutableDictionary dictionary]; _data[@"records"] = records;
    }
    NSArray *keys = [records.allKeys copy];
    for (NSString *k in keys) {
        id raw = records[k];
        if (![raw isKindOfClass:[NSDictionary class]]) { [records removeObjectForKey:k]; continue; }
        NSMutableDictionary *r = [raw mutableCopy];
        id work = r[@"work"];
        if (![work isKindOfClass:[NSDictionary class]]) {
            r[@"work"] = [@{@"zb":@0, @"jb":@0, @"zm":@0, @"jj":@0} mutableCopy];
        } else {
            NSMutableDictionary *w = [work mutableCopy];
            for (NSString *wk in @[@"zb", @"jb", @"zm", @"jj"]) if (![w[wk] isKindOfClass:[NSNumber class]]) w[wk] = @0;
            r[@"work"] = w;
        }
        id bt = r[@"bt"];
        if (![bt isKindOfClass:[NSArray class]]) r[@"bt"] = [NSMutableArray array];
        else {
            NSMutableArray *clean = [NSMutableArray array];
            for (id b in bt) {
                if (![b isKindOfClass:[NSDictionary class]]) continue;
                NSMutableDictionary *bb = [b mutableCopy];
                if (![bb[@"name"] isKindOfClass:[NSString class]]) bb[@"name"] = @"";
                if (![bb[@"money"] isKindOfClass:[NSNumber class]]) bb[@"money"] = @0;
                [clean addObject:bb];
            }
            r[@"bt"] = clean;
        }
        id leave = r[@"leave"];
        if (leave && ![leave isKindOfClass:[NSDictionary class]]) [r removeObjectForKey:@"leave"];
        else if ([leave isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *lv = [leave mutableCopy];
            if (![lv[@"hour"] isKindOfClass:[NSNumber class]]) lv[@"hour"] = @0;
            if (![lv[@"multiple"] isKindOfClass:[NSNumber class]]) lv[@"multiple"] = @1;
            if (![lv[@"rule"] isKindOfClass:[NSString class]]) lv[@"rule"] = @"hour";
            if (![lv[@"type"] isKindOfClass:[NSString class]]) lv[@"type"] = @"xiu";
            if (![lv[@"money"] isKindOfClass:[NSNumber class]]) lv[@"money"] = @0;
            r[@"leave"] = lv;
        }
        if (![r[@"settle"] isKindOfClass:[NSNumber class]]) r[@"settle"] = @0;
        id note = r[@"note"];
        if (note && ![note isKindOfClass:[NSString class]]) r[@"note"] = @"";
        id pid = r[@"projectId"];
        if (![pid isKindOfClass:[NSString class]]) r[@"projectId"] = self.settings[@"projectId"] ?: @"default";
        id cid = r[@"classId"];
        if (![cid isKindOfClass:[NSString class]]) r[@"classId"] = self.settings[@"currentClass"] ?: @"1";
        records[k] = r;
    }
    for (NSString *key in @[@"bonuses", @"deductions"]) {
        id dict = _data[key];
        if (![dict isKindOfClass:[NSMutableDictionary class]]) { _data[key] = [NSMutableDictionary dictionary]; continue; }
        NSMutableDictionary *bd = dict;
        for (NSString *mk in [bd.allKeys copy]) {
            id arr = bd[mk];
            if (![arr isKindOfClass:[NSArray class]]) { [bd removeObjectForKey:mk]; continue; }
            NSMutableArray *clean = [NSMutableArray array];
            for (id b in arr) {
                if (![b isKindOfClass:[NSDictionary class]]) continue;
                NSMutableDictionary *bb = [b mutableCopy];
                if (![bb[@"name"] isKindOfClass:[NSString class]]) bb[@"name"] = @"补扣";
                if (![bb[@"money"] isKindOfClass:[NSNumber class]]) bb[@"money"] = @0;
                [clean addObject:bb];
            }
            bd[mk] = clean;
        }
    }
}
- (void)load {
    NSData *d = [NSData dataWithContentsOfFile:[self filePath]];
    if (d) {
        NSError *e = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:&e];
        if ([obj isKindOfClass:[NSMutableDictionary class]] && [obj[@"v"] intValue] == 2) {
            _data = obj;
            if (!_data[@"settings"]) _data[@"settings"] = [self defaults][@"settings"];
            if (!_data[@"records"]) _data[@"records"] = [NSMutableDictionary dictionary];
            if (!_data[@"plans"]) _data[@"plans"] = [NSMutableDictionary dictionary];
            if (!_data[@"bonuses"]) _data[@"bonuses"] = [NSMutableDictionary dictionary];
            if (!_data[@"deductions"]) _data[@"deductions"] = [NSMutableDictionary dictionary];
            [self sanitizeData];
            [self autoCarry];
            return;
        }
    }
    _data = [self defaults];
    [self sanitizeData];
    [self save];
}
- (void)save {
    if (!_data) return;
    NSError *e = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:_data options:NSJSONWritingPrettyPrinted error:&e];
    if (d) [d writeToFile:[self filePath] atomically:YES];
}
- (NSMutableDictionary *)settings { return _data[@"settings"]; }
- (NSArray *)projects { return _data[@"projects"] ?: @[]; }
- (NSArray *)classes { return _data[@"classes"] ?: @[]; }
- (NSDictionary *)projectWithId:(NSString *)pid {
    for (NSDictionary *p in self.projects) if ([p[@"id"] isEqual:pid]) return p;
    return self.projects.firstObject;
}
- (NSDictionary *)classWithId:(NSString *)cid {
    for (NSDictionary *c in self.classes) if ([c[@"id"] isEqual:cid]) return c;
    return nil;
}
- (NSDictionary *)recordForDate:(NSString *)date { return _data[@"records"][date]; }
- (void)setRecord:(NSDictionary *)rec forDate:(NSString *)date {
    _data[@"records"][date] = [rec mutableCopy];
    [self save];
}
- (void)removeRecordForDate:(NSString *)date {
    [_data[@"records"] removeObjectForKey:date];
    [self save];
}
- (NSString *)planForDate:(NSString *)date { id p = _data[@"plans"][date]; return [p isKindOfClass:[NSString class]] ? p : @""; }
- (void)setPlan:(NSString *)classId forDate:(NSString *)date {
    if (classId.length == 0) [_data[@"plans"] removeObjectForKey:date];
    else _data[@"plans"][date] = classId;
    [self save];
}
- (double)rateForProject:(NSString *)pid type:(NSString *)type {
    NSDictionary *p = [self projectWithId:pid];
    return [p[@"rates"][type] doubleValue];
}
- (double)dayHours:(NSDictionary *)rec {
    if (!rec) return 0;
    id w = rec[@"work"];
    if (![w isKindOfClass:[NSDictionary class]]) return 0;
    return [w[@"zb"] doubleValue] + [w[@"jb"] doubleValue] + [w[@"zm"] doubleValue] + [w[@"jj"] doubleValue];
}
- (double)annualLeaveTotalDays {
    return MAX(0, [self.settings[@"annualLeaveDays"] doubleValue]);
}
- (double)annualLeaveUsedDaysForYear:(NSInteger)year {
    double hours = 0;
    NSString *prefix = [NSString stringWithFormat:@"%04ld-", (long)year];
    for (NSString *k in _data[@"records"]) {
        if (![k hasPrefix:prefix]) continue;
        NSDictionary *r = _data[@"records"][k];
        id raw = r[@"leave"];
        if (![raw isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *lv = raw;
        if (![lv[@"type"] isEqual:@"xiu"]) continue;
        hours += [lv[@"hour"] doubleValue];
    }
    return GSRound2(hours / 8.0);
}
- (double)annualLeaveRemainingDaysForYear:(NSInteger)year {
    return GSRound2([self annualLeaveTotalDays] - [self annualLeaveUsedDaysForYear:year]);
}
- (double)leavePay:(NSDictionary *)rec {
    id rawLeave = rec[@"leave"];
    if (![rawLeave isKindOfClass:[NSDictionary class]]) return 0;
    NSDictionary *l = rawLeave;
    double h = [l[@"hour"] doubleValue];
    if (h <= 0) return 0;
    if ([l[@"rule"] isEqual:@"money"]) return [l[@"money"] doubleValue];
    return h * [self rateForProject:rec[@"projectId"] type:@"zb"] * [l[@"multiple"] doubleValue];
}
- (double)dayPay:(NSDictionary *)rec {
    if (!rec) return 0;
    double settle = [rec[@"settle"] doubleValue];
    double bt = 0;
    id rawBT = rec[@"bt"];
    if ([rawBT isKindOfClass:[NSArray class]]) for (NSDictionary *b in rawBT) if ([b isKindOfClass:[NSDictionary class]]) bt += [b[@"money"] doubleValue];
    if (settle > 0) return GSRound2(settle + bt);
    double p = 0;
    id rawWork = rec[@"work"];
    NSDictionary *w = [rawWork isKindOfClass:[NSDictionary class]] ? rawWork : @{};
    for (NSString *k in @[@"zb", @"jb", @"zm", @"jj"]) p += [w[k] doubleValue] * [self rateForProject:rec[@"projectId"] type:k];
    p += [self leavePay:rec];
    return GSRound2(p + bt);
}
- (NSString *)daySummary:(NSDictionary *)rec {
    if (!rec) return @"未记录";
    id rawWork = rec[@"work"];
    NSDictionary *w = [rawWork isKindOfClass:[NSDictionary class]] ? rawWork : @{};
    double zb = [w[@"zb"] doubleValue], jb = [w[@"jb"] doubleValue];
    if (zb > 0 && jb > 0) return [NSString stringWithFormat:@"%@+%@", GSNum(zb), GSNum(jb)];
    double h = [self dayHours:rec];
    if (h > 0) return [NSString stringWithFormat:@"%@h", GSNum(h)];
    if ([rec[@"leave"] isKindOfClass:[NSDictionary class]]) return [NSString stringWithFormat:@"休%@", GSNum([rec[@"leave"][@"hour"] doubleValue])];
    if ([rec[@"settle"] doubleValue] > 0) return @"日结";
    return @"记";
}
- (NSDictionary *)periodRange:(NSInteger)year month:(NSInteger)month {
    NSString *prefix = [NSString stringWithFormat:@"%04ld-%02ld", (long)year, (long)month];
    for (NSDictionary *p in self.settings[@"customPeriods"] ?: @[]) {
        if ([p[@"start"] hasPrefix:prefix]) return @{@"start":p[@"start"], @"end":p[@"end"], @"label":[NSString stringWithFormat:@"%@ - %@", [p[@"start"] substringFromIndex:5], [p[@"end"] substringFromIndex:5]]};
    }
    NSInteger day = [self.settings[@"period"] integerValue];
    if (day < 1 || day > 29) day = 26;
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSInteger curDays = GSDaysInMonth(year, month);
    if (day == 1) {
        NSString *s = [NSString stringWithFormat:@"%04ld-%02ld-01", (long)year, (long)month];
        NSString *e = [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)year, (long)month, (long)curDays];
        return @{@"start":s, @"end":e, @"label":@"1号 - 月底"};
    }
    NSDateComponents *nc = GSMonthAdd(year, month, 1);
    NSInteger nextDays = GSDaysInMonth(nc.year, nc.month);
    NSInteger sd = MIN(day, curDays);
    NSInteger ed = MIN(day - 1, nextDays);
    NSDateComponents *ps = [[NSDateComponents alloc] init]; ps.year = year; ps.month = month; ps.day = sd;
    NSDateComponents *ee = [[NSDateComponents alloc] init]; ee.year = nc.year; ee.month = nc.month; ee.day = ed;
    NSDate *sDate = [cal dateFromComponents:ps], *eDate = [cal dateFromComponents:ee];
    return @{@"start":GSKeyFromDate(sDate), @"end":GSKeyFromDate(eDate),
             @"label":[NSString stringWithFormat:@"%ld.%ld - %ld.%ld", (long)month, (long)sd, (long)nc.month, (long)ed]};
}
- (NSDictionary *)monthStats:(NSInteger)year month:(NSInteger)month usePeriod:(BOOL)usePeriod {
    NSDictionary *range = [self periodRange:year month:month];
    NSString *prefix = [NSString stringWithFormat:@"%04ld-%02ld-", (long)year, (long)month];
    double days = 0, hours = 0, pay = 0, zb = 0, jb = 0, zm = 0, jj = 0, bonus = 0, deduct = 0;
    for (NSString *k in _data[@"records"]) {
        if (usePeriod) { if ([k compare:range[@"start"]] == NSOrderedAscending || [k compare:range[@"end"]] == NSOrderedDescending) continue; }
        else if (![k hasPrefix:prefix]) continue;
        NSDictionary *r = _data[@"records"][k];
        days += 1; hours += [self dayHours:r]; pay += [self dayPay:r];
        id rawWork = r[@"work"];
        NSDictionary *w = [rawWork isKindOfClass:[NSDictionary class]] ? rawWork : @{};
        zb += [w[@"zb"] doubleValue]; jb += [w[@"jb"] doubleValue]; zm += [w[@"zm"] doubleValue]; jj += [w[@"jj"] doubleValue];
        id rawBT = r[@"bt"];
        if ([rawBT isKindOfClass:[NSArray class]]) for (NSDictionary *b in rawBT) {
            if (![b isKindOfClass:[NSDictionary class]]) continue;
            double m = [b[@"money"] doubleValue]; if (m >= 0) bonus += m; else deduct += -m;
        }
    }
    NSString *mk = [NSString stringWithFormat:@"%04ld-%02ld", (long)year, (long)month];
    for (NSDictionary *b in _data[@"bonuses"][mk] ?: @[]) { double m = [b[@"money"] doubleValue]; bonus += m; pay += m; }
    for (NSDictionary *b in _data[@"deductions"][mk] ?: @[]) { double m = [b[@"money"] doubleValue]; deduct += m; pay -= m; }
    return @{@"days":@(days), @"hours":@(GSRound2(hours)), @"pay":@(GSRound2(pay)), @"zb":@(GSRound2(zb)), @"jb":@(GSRound2(jb)),
             @"zm":@(GSRound2(zm)), @"jj":@(GSRound2(jj)), @"bonus":@(GSRound2(bonus)), @"deduct":@(GSRound2(deduct)),
             @"avg":@(hours > 0 ? GSRound2(pay / hours) : 0), @"label":range[@"label"], @"start":range[@"start"], @"end":range[@"end"]};
}
- (NSDictionary *)yearStats:(NSInteger)year {
    double pay = 0, hours = 0, days = 0, ot = 0, bonus = 0, deduct = 0;
    NSMutableArray *months = [NSMutableArray array];
    for (NSInteger m = 1; m <= 12; m++) {
        NSDictionary *s = [self monthStats:year month:m usePeriod:NO];
        [months addObject:s];
        pay += [s[@"pay"] doubleValue]; hours += [s[@"hours"] doubleValue]; days += [s[@"days"] doubleValue];
        ot += [s[@"jb"] doubleValue] + [s[@"zm"] doubleValue] + [s[@"jj"] doubleValue];
        bonus += [s[@"bonus"] doubleValue]; deduct += [s[@"deduct"] doubleValue];
    }
    return @{@"months":months, @"pay":@(GSRound2(pay)), @"hours":@(GSRound2(hours)), @"days":@(days),
             @"ot":@(GSRound2(ot)), @"bonus":@(GSRound2(bonus)), @"deduct":@(GSRound2(deduct)),
             @"workPay":@(GSRound2(pay - bonus + deduct)), @"avg":@(hours > 0 ? GSRound2(pay / hours) : 0)};
}
- (NSArray<NSString *> *)dailyKeysForYear:(NSInteger)year month:(NSInteger)month {
    NSString *prefix = [NSString stringWithFormat:@"%04ld-%02ld-", (long)year, (long)month];
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *k in _data[@"records"]) if ([k hasPrefix:prefix]) [a addObject:k];
    return [a sortedArrayUsingSelector:@selector(compare:)];
}
- (NSString *)monthKey:(NSInteger)year month:(NSInteger)month { return [NSString stringWithFormat:@"%04ld-%02ld", (long)year, (long)month]; }
- (NSArray *)extrasForKind:(NSString *)kind year:(NSInteger)year month:(NSInteger)month {
    NSDictionary *dict = [kind isEqual:@"bonus"] ? _data[@"bonuses"] : _data[@"deductions"];
    return dict[[self monthKey:year month:month]] ?: @[];
}
- (void)addExtra:(NSString *)kind year:(NSInteger)year month:(NSInteger)month name:(NSString *)name money:(double)money note:(NSString *)note {
    NSMutableDictionary *dict = [kind isEqual:@"bonus"] ? _data[@"bonuses"] : _data[@"deductions"];
    NSString *mk = [self monthKey:year month:month];
    NSMutableArray *a = dict[mk];
    if (!a) { a = [NSMutableArray array]; dict[mk] = a; }
    [a addObject:[@{@"id":[NSUUID UUID].UUIDString, @"name":name ?: @"补扣", @"money":@(fabs(money)), @"note":note ?: @"", @"auto":@NO} mutableCopy]];
    [self save];
}
- (void)deleteExtra:(NSString *)kind year:(NSInteger)year month:(NSInteger)month index:(NSInteger)index {
    NSMutableDictionary *dict = [kind isEqual:@"bonus"] ? _data[@"bonuses"] : _data[@"deductions"];
    NSMutableArray *a = dict[[self monthKey:year month:month]];
    if (index >= 0 && index < (NSInteger)a.count) { [a removeObjectAtIndex:index]; [self save]; }
}
- (void)importLastMonthToKind:(NSString *)kind year:(NSInteger)year month:(NSInteger)month {
    NSDateComponents *prev = GSMonthAdd(year, month, -1);
    NSArray *src = [self extrasForKind:kind year:prev.year month:prev.month];
    if (src.count == 0) return;
    NSMutableDictionary *dict = [kind isEqual:@"bonus"] ? _data[@"bonuses"] : _data[@"deductions"];
    NSString *mk = [self monthKey:year month:month];
    NSMutableArray *a = dict[mk];
    if (!a) { a = [NSMutableArray array]; dict[mk] = a; }
    for (NSDictionary *b in src) {
        BOOL exists = NO;
        for (NSDictionary *x in a) if ([x[@"name"] isEqual:b[@"name"]] && fabs([x[@"money"] doubleValue] - [b[@"money"] doubleValue]) < 0.001) { exists = YES; break; }
        if (!exists) {
            [a addObject:[@{@"id":[NSUUID UUID].UUIDString, @"name":b[@"name"], @"money":b[@"money"], @"note":@"上月导入", @"auto":@YES} mutableCopy]];
        }
    }
    [self save];
}
- (void)autoCarry {
    if (!_data) return;
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSInteger y = [cal component:NSCalendarUnitYear fromDate:now];
    NSInteger m = [cal component:NSCalendarUnitMonth fromDate:now];
    NSString *cur = [self monthKey:y month:m];
    if ([self.settings[@"autoCarryMonth"] isEqual:cur]) return;
    [self importLastMonthToKind:@"bonus" year:y month:m];
    [self importLastMonthToKind:@"deduct" year:y month:m];
    self.settings[@"autoCarryMonth"] = cur;
    [self save];
}
- (NSDictionary *)defaultWorkForClass:(NSString *)cid {
    id d = self.settings[@"classDefaults"][cid];
    if ([d isKindOfClass:[NSDictionary class]]) return d;
    id fallback = self.settings[@"defaultWork"];
    return [fallback isKindOfClass:[NSDictionary class]] ? fallback : @{@"zb":@8, @"jb":@2, @"zm":@10, @"jj":@10};
}
- (NSString *)allowanceNameForClass:(NSString *)cid {
    NSDictionary *c = [self classWithId:cid];
    NSString *name = c[@"name"] ?: @"";
    if ([name containsString:@"夜"] || [name containsString:@"中"] || [name containsString:@"晚"]) return @"夜班补助";
    if ([name containsString:@"白"] || [name containsString:@"早"]) return @"白班补助";
    return nil;
}
- (void)ensureAutoAllowance:(NSMutableDictionary *)rec {
    if (!rec || ![self.settings[@"autoBonus"] boolValue]) return;
    NSString *type = rec[@"type"];
    if ([type isEqual:@"xiu"]) return;
    double workTotal = 0;
    id workObj = rec[@"work"];
    if ([workObj isKindOfClass:[NSDictionary class]]) for (NSString *k in @[@"zb", @"jb", @"zm", @"jj"]) workTotal += [workObj[k] doubleValue];
    BOOL hasLeave = [rec[@"leave"] isKindOfClass:[NSDictionary class]];
    if (workTotal <= 0 && !hasLeave) return;
    NSString *allowName = [self allowanceNameForClass:rec[@"classId"]];
    if (!allowName) return;
    BOOL night = [allowName isEqual:@"夜班补助"];
    double amount = night ? [self.settings[@"nightAllowance"] doubleValue] : [self.settings[@"dayAllowance"] doubleValue];
    if (amount <= 0) return;
    id raw = rec[@"bt"];
    NSMutableArray *bt = [raw isKindOfClass:[NSArray class]] ? [raw mutableCopy] : [NSMutableArray array];
    for (NSDictionary *b in bt) if ([b isKindOfClass:[NSDictionary class]] && [b[@"name"] isEqual:allowName]) { rec[@"bt"] = bt; return; }
    [bt addObject:[@{@"name":allowName, @"money":@(amount), @"note":@"自动补助", @"autoAllowance":@YES} mutableCopy]];
    rec[@"bt"] = bt;
}
- (void)setClassDefault:(NSString *)cid key:(NSString *)key value:(double)value {
    NSMutableDictionary *cd = self.settings[@"classDefaults"];
    NSMutableDictionary *d = cd[cid];
    if (!d) { d = [NSMutableDictionary dictionary]; cd[cid] = d; }
    d[key] = @(value);
    [self save];
}
- (NSInteger)removeAutoAllowanceNamed:(NSString *)name {
    NSInteger removed = 0;
    for (NSString *key in [_data[@"records"] allKeys]) {
        NSMutableDictionary *rec = _data[@"records"][key];
        id raw = rec[@"bt"];
        if (![raw isKindOfClass:[NSArray class]]) continue;
        NSMutableArray *kept = [NSMutableArray array];
        BOOL changed = NO;
        for (NSDictionary *b in raw) {
            if (![b isKindOfClass:[NSDictionary class]]) continue;
            BOOL autoEntry = ([b[@"autoAllowance"] isKindOfClass:[NSNumber class]] && [b[@"autoAllowance"] boolValue]) || [b[@"note"] isEqual:@"自动补助"];
            if (autoEntry && [b[@"name"] isEqual:name]) { changed = YES; removed++; continue; }
            [kept addObject:b];
        }
        if (changed) rec[@"bt"] = kept;
    }
    if (removed > 0) [self save];
    return removed;
}
- (void)clearAllRecords {
    _data[@"records"] = [NSMutableDictionary dictionary];
    _data[@"plans"] = [NSMutableDictionary dictionary];
    _data[@"bonuses"] = [NSMutableDictionary dictionary];
    _data[@"deductions"] = [NSMutableDictionary dictionary];
    [self save];
}
- (void)importLastMonthBothToYear:(NSInteger)year month:(NSInteger)month {
    [self importLastMonthToKind:@"bonus" year:year month:month];
    [self importLastMonthToKind:@"deduct" year:year month:month];
}
- (NSDictionary *)backupDictionary {
    NSMutableArray *days = [NSMutableArray array];
    double totalHours = 0, totalPay = 0;
    NSArray *keys = [_data[@"records"] allKeys];
    keys = [keys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *date in keys) {
        NSDictionary *rec = _data[@"records"][date];
        if (![rec isKindOfClass:[NSDictionary class]]) continue;
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        item[@"d"] = date;
        if (rec[@"classId"]) item[@"c"] = rec[@"classId"];
        if (rec[@"projectId"]) item[@"p"] = rec[@"projectId"];
        item[@"t"] = rec[@"type"] ?: @"zb";
        NSDictionary *w = rec[@"work"];
        item[@"w"] = @[@([w[@"zb"] doubleValue]), @([w[@"jb"] doubleValue]), @([w[@"zm"] doubleValue]), @([w[@"jj"] doubleValue])];
        if ([rec[@"settle"] doubleValue] > 0) item[@"s"] = rec[@"settle"];
        if ([rec[@"bt"] isKindOfClass:[NSArray class]] && [rec[@"bt"] count]) item[@"b"] = rec[@"bt"];
        if ([rec[@"leave"] isKindOfClass:[NSDictionary class]]) item[@"l"] = rec[@"leave"];
        if ([rec[@"note"] length]) item[@"n"] = rec[@"note"];
        [days addObject:item];
        totalHours += [self dayHours:rec];
        totalPay += [self dayPay:rec];
    }
    NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
    return @{
        @"app": @"工时记录",
        @"format": @"gsjilu-backup",
        @"version": @4,
        @"exportedAt": [fmt stringFromDate:[NSDate date]],
        @"summary": @{@"days": @(days.count), @"hours": @(GSRound2(totalHours)), @"pay": @(GSRound2(totalPay))},
        @"settings": self.settings ?: @{},
        @"projects": self.projects ?: @[],
        @"classes": self.classes ?: @[],
        @"plans": _data[@"plans"] ?: @{},
        @"extras": @{@"bonus": _data[@"bonuses"] ?: @{}, @"deduct": _data[@"deductions"] ?: @{}},
        @"days": days
    };
}
- (BOOL)importBackupData:(NSDictionary *)raw {
    if (![raw isKindOfClass:[NSDictionary class]]) return NO;
    NSMutableDictionary *newData = nil;
    if ([raw[@"format"] isEqual:@"gsjilu-backup"] && [raw[@"days"] isKindOfClass:[NSArray class]]) {
        newData = [self defaults];
        if ([raw[@"settings"] isKindOfClass:[NSDictionary class]]) newData[@"settings"] = [raw[@"settings"] mutableCopy];
        if ([raw[@"projects"] isKindOfClass:[NSArray class]]) newData[@"projects"] = [raw[@"projects"] mutableCopy];
        if ([raw[@"classes"] isKindOfClass:[NSArray class]]) newData[@"classes"] = [raw[@"classes"] mutableCopy];
        if ([raw[@"plans"] isKindOfClass:[NSDictionary class]]) newData[@"plans"] = [raw[@"plans"] mutableCopy];
        NSDictionary *extras = [raw[@"extras"] isKindOfClass:[NSDictionary class]] ? raw[@"extras"] : @{};
        if ([extras[@"bonus"] isKindOfClass:[NSDictionary class]]) newData[@"bonuses"] = [extras[@"bonus"] mutableCopy];
        if ([extras[@"deduct"] isKindOfClass:[NSDictionary class]]) newData[@"deductions"] = [extras[@"deduct"] mutableCopy];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        NSString *defaultClass = newData[@"settings"][@"currentClass"] ?: @"1";
        NSString *defaultProject = newData[@"settings"][@"projectId"] ?: @"default";
        for (NSDictionary *item in raw[@"days"]) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSString *date = item[@"d"];
            if (![date isKindOfClass:[NSString class]] || date.length != 10) continue;
            NSMutableDictionary *rec = [NSMutableDictionary dictionary];
            rec[@"classId"] = [item[@"c"] isKindOfClass:[NSString class]] ? item[@"c"] : defaultClass;
            rec[@"projectId"] = [item[@"p"] isKindOfClass:[NSString class]] ? item[@"p"] : defaultProject;
            rec[@"type"] = [item[@"t"] isKindOfClass:[NSString class]] ? item[@"t"] : GSDayKind(date);
            NSArray *w = [item[@"w"] isKindOfClass:[NSArray class]] ? item[@"w"] : @[];
            rec[@"work"] = [@{@"zb": w.count > 0 ? w[0] : @0, @"jb": w.count > 1 ? w[1] : @0,
                              @"zm": w.count > 2 ? w[2] : @0, @"jj": w.count > 3 ? w[3] : @0} mutableCopy];
            if (item[@"s"]) rec[@"settle"] = item[@"s"];
            if ([item[@"b"] isKindOfClass:[NSArray class]]) rec[@"bt"] = [item[@"b"] mutableCopy];
            if ([item[@"l"] isKindOfClass:[NSDictionary class]]) rec[@"leave"] = [item[@"l"] mutableCopy];
            if ([item[@"n"] isKindOfClass:[NSString class]]) rec[@"note"] = item[@"n"];
            records[date] = rec;
        }
        newData[@"records"] = records;
    } else if ([raw[@"records"] isKindOfClass:[NSDictionary class]]) {
        newData = [raw mutableCopy];
    } else {
        return NO;
    }
    newData[@"v"] = @2;
    _data = newData;
    [self sanitizeData];
    [self save];
    return YES;
}

- (NSString *)reportTextForYear:(NSInteger)year month:(NSInteger)month {
    NSDictionary *st = [self monthStats:year month:month usePeriod:YES];
    NSMutableString *s = [NSMutableString stringWithFormat:@"%ld年%ld月 工时报表\n考勤周期 %@\n出勤 %@ 天 · 工时 %@H · 工资 %@\n---\n", (long)year, (long)month, st[@"label"], GSNum([st[@"days"] doubleValue]), GSNum([st[@"hours"] doubleValue]), GSMoney([st[@"pay"] doubleValue])];
    NSDictionary *records = _data[@"records"];
    NSArray *keys = records.allKeys;
    NSArray *sorted = [keys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *k in sorted) {
        if ([k compare:st[@"start"]] == NSOrderedAscending || [k compare:st[@"end"]] == NSOrderedDescending) continue;
        NSDictionary *r = _data[@"records"][k];
        [s appendFormat:@"%@ %@ %@\n", k, [self daySummary:r], GSMoney([self dayPay:r])];
    }
    [s appendFormat:@"---\n补贴 %@ · 扣款 %@\n", GSMoney([st[@"bonus"] doubleValue]), GSMoney([st[@"deduct"] doubleValue])];
    return s;
}
@end
