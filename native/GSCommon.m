#import "GSCommon.h"
#import "GSStore.h"
#import <objc/runtime.h>

const CGFloat GSPageMargin = 18.0;
const CGFloat GSCardPadding = 18.0;
const CGFloat GSCardRadius = 20.0;

static NSCalendar *GSGregorianCalendar(void);
static UIWindow *GSKeyWindow(void);
static NSCache<NSString *, UIColor *> *GSColorCache(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 96; });
    return cache;
}
UIColor *GSColorHex(NSString *hex) { return GSColorHexA(hex, 1.0); }
UIColor *GSColorHexA(NSString *hex, CGFloat alpha) {
    NSString *key = [NSString stringWithFormat:@"%@|%.3f", hex ?: @"", alpha];
    UIColor *cached = [GSColorCache() objectForKey:key];
    if (cached) return cached;
    NSString *s = [(hex ?: @"#000000") stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (s.length == 3) {
        s = [NSString stringWithFormat:@"%c%c%c%c%c%c", [s characterAtIndex:0], [s characterAtIndex:0], [s characterAtIndex:1], [s characterAtIndex:1], [s characterAtIndex:2], [s characterAtIndex:2]];
    }
    unsigned int v = 0; [[NSScanner scannerWithString:s] scanHexInt:&v];
    UIColor *c = [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:alpha];
    if (c) [GSColorCache() setObject:c forKey:key];
    return c;
}
UIColor *GSTextPrimary(void) { return GSColorHex(@"#101828"); }
UIColor *GSTextSecondary(void) { return GSColorHex(@"#667085"); }
UIColor *GSTextTertiary(void) { return GSColorHex(@"#98A2B3"); }
UIColor *GSTextStrong(void) { return GSColorHex(@"#344054"); }
UIColor *GSSurfaceMuted(void) { return GSColorHex(@"#F4F7FB"); }
UIColor *GSBorderColor(void) { return GSColorHex(@"#EDF1F7"); }
UIColor *GSSuccessColor(void) { return GSColorHex(@"#067647"); }
UIColor *GSWarningColor(void) { return GSColorHex(@"#B54708"); }
UIColor *GSDangerColor(void) { return GSColorHex(@"#B42318"); }
UIColor *GSMoneyColor(void) { return GSColorHex(@"#B45309"); }

UIFont *GSFont(CGFloat size, UIFontWeight weight) {
    // Keep tiny captions readable, but leave 1pt spacer labels untouched.
    if (size > 2.0 && size < 10.0) size = 10.0;
    return [UIFont systemFontOfSize:size weight:weight];
}
double GSRound2(double v) { return round(v * 100.0) / 100.0; }
NSString *GSNum(double v) {
    if (fabs(v - round(v)) < 0.001) return [NSString stringWithFormat:@"%.0f", v];
    return [NSString stringWithFormat:@"%.2f", v];
}
NSString *GSMoney(double v) {
    static NSNumberFormatter *f; static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterCurrencyStyle;
        f.currencySymbol = @"¥";
        f.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        f.minimumFractionDigits = 0; f.maximumFractionDigits = 2;
    });
    return [f stringFromNumber:@(GSRound2(v))] ?: @"¥0";
}
BOOL GSIsPhoneSmall(void) { return [UIScreen mainScreen].bounds.size.width < 375; }

NSNotificationName const GSThemeDidChangeNotification = @"GSThemeDidChangeNotification";
NSNotificationName const GSHeaderRadiusDidChangeNotification = @"GSHeaderRadiusDidChangeNotification";
NSNotificationName const GSUIConfigDidChangeNotification = @"GSUIConfigDidChangeNotification";
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

static NSDateFormatter *GSDateFormatter(void) {
    static NSDateFormatter *f; static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        f.dateFormat = @"yyyy-MM-dd";
    });
    return f;
}
NSString *GSKeyFromDate(NSDate *date) {
    if (!date) return @"";
    return [GSDateFormatter() stringFromDate:date] ?: @"";
}
NSDate *GSDateFromKey(NSString *key) {
    return [GSDateFormatter() dateFromString:key ?: @""] ?: [NSDate date];
}
NSString *GSTodayKey(void) { return GSKeyFromDate([NSDate date]); }
NSString *GSWeekdayName(NSString *key) {
    NSDate *d = GSDateFromKey(key);
    NSCalendar *cal = GSGregorianCalendar();
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
static NSCalendar *GSGregorianCalendar(void) {
    static NSCalendar *cal; static dispatch_once_t once;
    dispatch_once(&once, ^{ cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian]; });
    return cal;
}
NSInteger GSDaysInMonth(NSInteger year, NSInteger month) {
    NSCalendar *cal = GSGregorianCalendar();
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
static NSCalendar *GSLunarCalendar(void) {
    static NSCalendar *cal; static dispatch_once_t once;
    dispatch_once(&once, ^{ cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierChinese]; });
    return cal;
}
NSString *GSLunarDay(NSDate *date) {
    NSCalendar *lunar = GSLunarCalendar();
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
    NSCalendar *cal = GSGregorianCalendar();
    NSInteger w = [cal component:NSCalendarUnitWeekday fromDate:GSDateFromKey(key)];
    return (w == 1 || w == 7) ? @"zm" : @"zb";
}
NSString *GSKindName(NSString *kind) {
    if ([kind isEqualToString:@"jj"]) return @"节假";
    if ([kind isEqualToString:@"zm"]) return @"周末";
    if ([kind isEqualToString:@"xiu"]) return @"休假";
    return @"正班";
}
static NSCache<NSString *, UIImage *> *GSIconCache(void) {
    static NSCache *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; cache.countLimit = 128; });
    return cache;
}
UIImage *GSIcon(NSString *name, CGFloat size) {
    if (name.length == 0) return nil;
    NSString *key = [NSString stringWithFormat:@"%@|%.1f", name, size];
    UIImage *cached = [GSIconCache() objectForKey:key];
    if (cached) return cached;
    UIImageSymbolConfiguration *c = [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold];
    UIImage *image = [[UIImage systemImageNamed:name withConfiguration:c] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (image) [GSIconCache() setObject:image forKey:key];
    return image;
}
void GSHaptic(void) {
    static UIImpactFeedbackGenerator *generator;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight]; });
    [generator prepare];
    [generator impactOccurred];
}
NSAttributedString *GSPlaceholder(NSString *text, UIFont *font) {
    return [[NSAttributedString alloc] initWithString:(text ?: @"") attributes:@{NSForegroundColorAttributeName:GSTextSecondary(), NSFontAttributeName:font ?: GSFont(14, UIFontWeightRegular)}];
}
void GSAnimateStack(UIStackView *stack) {
    if (!stack) return;
    NSArray<UIView *> *views = stack.arrangedSubviews;
    BOOL animations = [GSStore shared].settings[@"animations"] == nil || [[GSStore shared].settings[@"animations"] boolValue];
    if (!animations || !stack.window || UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *v in views) { v.alpha = 1; v.transform = CGAffineTransformIdentity; }
        return;
    }
    static char kGSStackAnimatedKey;
    if (objc_getAssociatedObject(stack, &kGSStackAnimatedKey)) {
        for (UIView *v in views) { v.alpha = 1; v.transform = CGAffineTransformIdentity; }
        return;
    }
    objc_setAssociatedObject(stack, &kGSStackAnimatedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSInteger limit = MIN((NSInteger)views.count, 8);
    for (NSInteger i = 0; i < (NSInteger)views.count; i++) {
        UIView *v = views[i];
        if (i >= limit) { v.alpha = 1; v.transform = CGAffineTransformIdentity; continue; }
        v.alpha = 0;
        v.transform = CGAffineTransformMakeTranslation(0, 8);
        [UIView animateWithDuration:0.28 delay:0.022 * i usingSpringWithDamping:0.92 initialSpringVelocity:0.25 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) animations:^{
            v.alpha = 1; v.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}
void GSAlert(NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *root = GSKeyWindow().rootViewController;
    if (!root) return;
    [root presentViewController:a animated:YES completion:nil];
}

static UIWindow *GSKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ws.windows) if (window.isKeyWindow) return window;
        if (ws.windows.firstObject) return ws.windows.firstObject;
    }
    return nil;
}
void GSToast(NSString *message) {
    UIWindow *w = GSKeyWindow();
    if (!w || message.length == 0) return;
    static __weak UIView *currentToast;
    UIView *old = currentToast;
    if (old) {
        [old.layer removeAllAnimations];
        [old removeFromSuperview];
    }
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = [UIColor colorWithWhite:0.06 alpha:.94];
    box.layer.cornerRadius = 20;
    box.layer.shadowColor = [UIColor colorWithWhite:0 alpha:.20].CGColor;
    box.layer.shadowOpacity = .22; box.layer.shadowRadius = 12; box.layer.shadowOffset = CGSizeMake(0, 6);
    box.alpha = 0; box.translatesAutoresizingMaskIntoConstraints = NO;
    box.accessibilityTraits = UIAccessibilityTraitStaticText;
    UILabel *l = [[UILabel alloc] init];
    l.text = message; l.font = GSFont(13, UIFontWeightMedium); l.textColor = UIColor.whiteColor;
    l.numberOfLines = 2; l.textAlignment = NSTextAlignmentCenter;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [box addSubview:l]; [w addSubview:box];
    [NSLayoutConstraint activateConstraints:@[
        [box.centerXAnchor constraintEqualToAnchor:w.centerXAnchor],
        [box.bottomAnchor constraintEqualToAnchor:w.safeAreaLayoutGuide.bottomAnchor constant:-106],
        [box.widthAnchor constraintLessThanOrEqualToAnchor:w.widthAnchor constant:-48],
        [l.topAnchor constraintEqualToAnchor:box.topAnchor constant:10],
        [l.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-10],
        [l.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16],
        [l.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16]
    ]];
    currentToast = box;
    box.transform = UIAccessibilityIsReduceMotionEnabled() ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 8);
    [UIView animateWithDuration:0.20 delay:0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState) animations:^{
        box.alpha = 1; box.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:2.1 options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState) animations:^{
            box.alpha = 0; box.transform = UIAccessibilityIsReduceMotionEnabled() ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 6);
        } completion:^(BOOL f) { [box removeFromSuperview]; }];
    }];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}
