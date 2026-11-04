#import "GSCommon.h"

UIColor *GSColorHex(NSString *hex) { return GSColorHexA(hex, 1.0); }
UIColor *GSColorHexA(NSString *hex, CGFloat alpha) {
    NSString *s = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (s.length == 3) {
        s = [NSString stringWithFormat:@"%c%c%c%c%c%c", [s characterAtIndex:0], [s characterAtIndex:0], [s characterAtIndex:1], [s characterAtIndex:1], [s characterAtIndex:2], [s characterAtIndex:2]];
    }
    unsigned int v = 0; [[NSScanner scannerWithString:s] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:alpha];
}
UIFont *GSFont(CGFloat size, UIFontWeight weight) { return [UIFont systemFontOfSize:size weight:weight]; }
double GSRound2(double v) { return round(v * 100.0) / 100.0; }
NSString *GSNum(double v) {
    if (fabs(v - round(v)) < 0.001) return [NSString stringWithFormat:@"%.0f", v];
    return [NSString stringWithFormat:@"%.2f", v];
}
NSString *GSMoney(double v) {
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterCurrencyStyle;
    f.currencySymbol = @"¥";
    f.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    f.minimumFractionDigits = 0; f.maximumFractionDigits = 2;
    return [f stringFromNumber:@(GSRound2(v))];
}
BOOL GSIsPhoneSmall(void) { return [UIScreen mainScreen].bounds.size.width < 375; }

NSNotificationName const GSThemeDidChangeNotification = @"GSThemeDidChangeNotification";
NSNotificationName const GSHeaderRadiusDidChangeNotification = @"GSHeaderRadiusDidChangeNotification";
static NSString *GSThemeKey = @"blue";
static NSDictionary *GSThemeTable(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            @"blue":   @[@"海蓝", @"#1E5BD6", @"#2563EB"],
            @"teal":   @[@"青绿", @"#0F766E", @"#14B8A6"],
            @"purple": @[@"葡萄紫", @"#7C3AED", @"#8B5CF6"],
            @"orange": @[@"日落橙", @"#EA580C", @"#F97316"],
            @"pink":   @[@"樱花粉", @"#DB2777", @"#EC4899"],
            @"green":  @[@"森林绿", @"#16A34A", @"#22C55E"]
        };
    });
    return d;
}
NSArray<NSString *> *GSThemeKeys(void) { return @[@"blue", @"teal", @"purple", @"orange", @"pink", @"green"]; }
NSArray<NSString *> *GSThemeNames(void) { return @[@"海蓝", @"青绿", @"葡萄紫", @"日落橙", @"樱花粉", @"森林绿"]; }
void GSSetThemeKey(NSString *key) {
    GSThemeKey = [GSThemeTable()[key] isKindOfClass:[NSArray class]] ? [key copy] : @"blue";
}
NSString *GSThemeKeyValue(void) { return GSThemeKey ?: @"blue"; }
NSString *GSThemeNameValue(void) {
    NSArray *v = GSThemeTable()[GSThemeKeyValue()];
    return v.count > 0 ? v[0] : @"海蓝";
}
NSString *GSThemeHexValue(void) {
    NSArray *v = GSThemeTable()[GSThemeKeyValue()];
    return v.count > 1 ? v[1] : @"#1E5BD6";
}
UIColor *GSThemeColor(void) {
    return GSColorHex(GSThemeHexValue());
}
UIColor *GSThemeDarkColor(void) {
    NSArray *v = GSThemeTable()[GSThemeKeyValue()];
    return GSColorHex(v.count > 2 ? v[2] : @"#2563EB");
}
UIColor *GSThemeSoftColor(void) { return [GSThemeColor() colorWithAlphaComponent:.12]; }

NSString *GSKeyFromDate(NSDate *date) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM-dd";
    return [f stringFromDate:date];
}
NSDate *GSDateFromKey(NSString *key) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM-dd";
    return [f dateFromString:key] ?: [NSDate date];
}
NSString *GSTodayKey(void) { return GSKeyFromDate([NSDate date]); }
NSString *GSWeekdayName(NSString *key) {
    NSDate *d = GSDateFromKey(key);
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSInteger w = [cal component:NSCalendarUnitWeekday fromDate:d];
    NSArray *names = @[@"周日", @"周一", @"周二", @"周三", @"周四", @"周五", @"周六"];
    return names[(w - 1) % 7];
}
NSString *GSRelativeDay(NSString *key) {
    NSDate *a = GSDateFromKey(GSTodayKey());
    NSDate *b = GSDateFromKey(key);
    NSInteger n = (NSInteger)round([a timeIntervalSinceDate:b] / 86400.0);
    if (n == 0) return @"今天";
    if (n == 1) return @"1天前";
    if (n > 1) return [NSString stringWithFormat:@"%ld天前", (long)n];
    if (n == -1) return @"明天";
    return [NSString stringWithFormat:@"%ld天后", (long)labs((long)n)];
}
NSInteger GSDaysInMonth(NSInteger year, NSInteger month) {
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *c = [[NSDateComponents alloc] init]; c.year = year; c.month = month; c.day = 1;
    NSDate *d = [cal dateFromComponents:c];
    NSRange r = [cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:d];
    return r.length;
}
NSDateComponents *GSMonthAdd(NSInteger year, NSInteger month, NSInteger delta) {
    NSInteger idx = year * 12 + (month - 1) + delta;
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = idx / 12; c.month = (idx % 12 + 12) % 12 + 1; c.day = 1;
    return c;
}
static NSArray *GSLunarDays(void) {
    static NSArray *a; static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[@"初一",@"初二",@"初三",@"初四",@"初五",@"初六",@"初七",@"初八",@"初九",@"初十",
              @"十一",@"十二",@"十三",@"十四",@"十五",@"十六",@"十七",@"十八",@"十九",@"二十",
              @"廿一",@"廿二",@"廿三",@"廿四",@"廿五",@"廿六",@"廿七",@"廿八",@"廿九",@"三十"];
    });
    return a;
}
NSString *GSLunarDay(NSDate *date) {
    NSCalendar *lunar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierChinese];
    NSDateComponents *c = [lunar components:NSCalendarUnitDay fromDate:date];
    NSInteger d = c.day;
    if (d < 1 || d > 30) return @"";
    return GSLunarDays()[d - 1];
}
NSString *GSLunarFull(NSDate *date) {
    NSCalendar *lunar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierChinese];
    NSDateComponents *c = [lunar components:NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitYear fromDate:date];
    NSArray *months = @[@"正月",@"二月",@"三月",@"四月",@"五月",@"六月",@"七月",@"八月",@"九月",@"十月",@"冬月",@"腊月"];
    NSInteger m = c.month;
    if (m < 1 || m > 12) return GSLunarDay(date);
    NSString *month = months[m - 1];
    if (c.isLeapMonth) month = [@"闰" stringByAppendingString:month];
    return [month stringByAppendingString:GSLunarDay(date)];
}
static NSDictionary *GSHolidays(void) {
    static NSDictionary *d; static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            @"2026-01-01":@"元旦", @"2026-01-02":@"元旦", @"2026-01-03":@"元旦",
            @"2026-02-16":@"春节", @"2026-02-17":@"春节", @"2026-02-18":@"春节", @"2026-02-19":@"春节",
            @"2026-02-20":@"春节", @"2026-02-21":@"春节", @"2026-02-22":@"春节",
            @"2026-04-04":@"清明", @"2026-04-05":@"清明", @"2026-04-06":@"清明",
            @"2026-05-01":@"劳动节", @"2026-05-02":@"劳动节", @"2026-05-03":@"劳动节", @"2026-05-04":@"劳动节", @"2026-05-05":@"劳动节",
            @"2026-06-19":@"端午", @"2026-06-20":@"端午", @"2026-06-21":@"端午",
            @"2026-09-25":@"中秋", @"2026-09-26":@"中秋", @"2026-09-27":@"中秋",
            @"2026-10-01":@"国庆", @"2026-10-02":@"国庆", @"2026-10-03":@"国庆", @"2026-10-04":@"国庆",
            @"2026-10-05":@"国庆", @"2026-10-06":@"国庆", @"2026-10-07":@"国庆"
        };
    });
    return d;
}
static NSSet *GSWorkdays(void) {
    static NSSet *s; static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [NSSet setWithArray:@[@"2026-02-14", @"2026-02-28", @"2026-04-26", @"2026-05-09", @"2026-09-20", @"2026-10-10"]];
    });
    return s;
}
NSString *GSHolidayName(NSString *key) { return GSHolidays()[key]; }
BOOL GSIsWorkday(NSString *key) { return [GSWorkdays() containsObject:key]; }
NSString *GSDayKind(NSString *key) {
    if (GSHolidays()[key]) return @"jj";
    if (GSIsWorkday(key)) return @"zb";
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSInteger w = [cal component:NSCalendarUnitWeekday fromDate:GSDateFromKey(key)];
    return (w == 1 || w == 7) ? @"zm" : @"zb";
}
NSString *GSKindName(NSString *kind) {
    if ([kind isEqualToString:@"jj"]) return @"节假";
    if ([kind isEqualToString:@"zm"]) return @"周末";
    if ([kind isEqualToString:@"xiu"]) return @"休假";
    return @"正班";
}
UIImage *GSIcon(NSString *name, CGFloat size) {
    UIImageSymbolConfiguration *c = [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold];
    return [UIImage systemImageNamed:name withConfiguration:c];
}
void GSHaptic(void) {
    UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [g impactOccurred];
}
NSAttributedString *GSPlaceholder(NSString *text, UIFont *font) {
    return [[NSAttributedString alloc] initWithString:(text ?: @"") attributes:@{NSForegroundColorAttributeName:GSColorHex(@"#5D6B82"), NSFontAttributeName:font ?: GSFont(13, UIFontWeightRegular)}];
}
void GSAnimateStack(UIStackView *stack) {
    if (!stack) return;
    NSArray<UIView *> *views = stack.arrangedSubviews;
    if (!stack.window) {
        for (UIView *v in views) { v.alpha = 1; v.transform = CGAffineTransformIdentity; }
        return;
    }
    for (NSInteger i = 0; i < (NSInteger)views.count; i++) {
        UIView *v = views[i];
        v.alpha = 0;
        v.transform = CGAffineTransformMakeTranslation(0, 10);
        [UIView animateWithDuration:0.36 delay:0.035 * i usingSpringWithDamping:0.88 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
            v.alpha = 1; v.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}
void GSAlert(NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
    [root presentViewController:a animated:YES completion:nil];
}

void GSToast(NSString *message) {
    UIWindow *w = UIApplication.sharedApplication.windows.firstObject;
    if (!w) return;
    UILabel *l = [[UILabel alloc] init];
    l.text = message; l.font = GSFont(13, UIFontWeightMedium); l.textColor = UIColor.whiteColor;
    l.backgroundColor = [UIColor colorWithWhite:0.06 alpha:.92];
    l.textAlignment = NSTextAlignmentCenter; l.layer.cornerRadius = 18; l.clipsToBounds = YES;
    l.alpha = 0; l.translatesAutoresizingMaskIntoConstraints = NO;
    [w addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [l.centerXAnchor constraintEqualToAnchor:w.centerXAnchor],
        [l.bottomAnchor constraintEqualToAnchor:w.safeAreaLayoutGuide.bottomAnchor constant:-110],
        [l.heightAnchor constraintEqualToConstant:36],
        [l.widthAnchor constraintGreaterThanOrEqualToConstant:100]
    ]];
    [UIView animateWithDuration:.2 animations:^{ l.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:.25 delay:1.4 options:0 animations:^{ l.alpha = 0; } completion:^(BOOL f) { [l removeFromSuperview]; }];
    }];
}
