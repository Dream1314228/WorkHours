#import "GSCalendarView.h"
#import "GSStore.h"

@interface GSCalendarCell : UIView
@property (nonatomic, strong) UILabel *dayLabel;
@property (nonatomic, strong) UILabel *lunarLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *kindLabel;
@property (nonatomic, strong) UIView *shiftPill;
@property (nonatomic, strong) UIImageView *shiftIcon;
@property (nonatomic, strong) UILabel *shiftLabel;
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UIView *todayLine;
@property (nonatomic, copy) NSString *dateKey;
@property (nonatomic, assign) BOOL inMonth;
@property (nonatomic, assign) BOOL selected;
@end
@implementation GSCalendarCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 13;
        _dayLabel = GSLabel(@"", GSFont(17, UIFontWeightSemibold), GSColorHex(@"#101828"));
        _dayLabel.textAlignment = NSTextAlignmentCenter;
        _lunarLabel = GSLabel(@"", GSFont(9, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        _lunarLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel = GSLabel(@"", GSFont(9, UIFontWeightBold), GSColorHex(@"#B45309"));
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _kindLabel = GSLabel(@"", GSFont(8, UIFontWeightBold), GSColorHex(@"#B45309"));
        _shiftPill = [[UIView alloc] init];
        _shiftPill.layer.cornerRadius = 6;
        _shiftPill.hidden = YES;
        _shiftPill.userInteractionEnabled = NO;
        _shiftIcon = [[UIImageView alloc] init];
        _shiftIcon.contentMode = UIViewContentModeCenter;
        _shiftLabel = GSLabel(@"", GSFont(8, UIFontWeightBold), GSThemeColor());
        _shiftLabel.textAlignment = NSTextAlignmentCenter;
        _shiftLabel.adjustsFontSizeToFitWidth = YES;
        _shiftLabel.minimumScaleFactor = .7;
        [_shiftPill addSubview:_shiftIcon];
        [_shiftPill addSubview:_shiftLabel];
        _dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 6)];
        _dot.layer.cornerRadius = 3;
        _dot.layer.borderWidth = 1.5; _dot.layer.borderColor = [UIColor colorWithWhite:1 alpha:.9].CGColor;
        _todayLine = [[UIView alloc] init];
        _todayLine.backgroundColor = GSColorHex(@"#B45309");
        _todayLine.layer.cornerRadius = 1.5;
        [self addSubview:_dayLabel]; [self addSubview:_lunarLabel]; [self addSubview:_badgeLabel];
        [self addSubview:_kindLabel]; [self addSubview:_shiftPill]; [self addSubview:_dot]; [self addSubview:_todayLine];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    BOOL textMode = !_shiftLabel.hidden;
    CGFloat dayY = textMode ? 10 : 7;
    _dayLabel.frame = CGRectMake(0, dayY, w, 20);
    _lunarLabel.frame = CGRectMake(0, dayY + 20, w, 9);
    _badgeLabel.frame = CGRectMake(0, dayY + 29, w, 10);
    _kindLabel.frame = CGRectMake(w - 24, 3, 18, 10);
    _kindLabel.textAlignment = NSTextAlignmentRight;
    _shiftPill.frame = CGRectMake(0, 0, w, 11);
    if (textMode) {
        _shiftLabel.frame = CGRectMake(0, 1, w, 9);
    } else {
        _shiftIcon.frame = CGRectMake(w/2 - 4, 1, 8, 8);
    }
    _dot.frame = CGRectMake(w - 13, 7, 6, 6);
    _todayLine.frame = CGRectMake(w/2 - 8, CGRectGetMaxY(_badgeLabel.frame) + 2, 16, 2.5);
}
@end

@interface GSCalendarView ()
@property (nonatomic, strong) NSArray<UILabel *> *weekLabels;
@property (nonatomic, strong) NSMutableArray<GSCalendarCell *> *cells;
@end
@implementation GSCalendarView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.whiteColor;
        _weekLabels = @[];
        _cells = [NSMutableArray array];
        NSArray *names = @[@"一", @"二", @"三", @"四", @"五", @"六", @"日"];
        NSMutableArray *labs = [NSMutableArray array];
        for (NSString *n in names) {
            UILabel *l = GSLabel(n, GSFont(11, UIFontWeightMedium), GSColorHex(@"#5D6B82"));
            l.textAlignment = NSTextAlignmentCenter;
            [self addSubview:l]; [labs addObject:l];
        }
        _weekLabels = labs;
        for (NSInteger i = 0; i < 42; i++) {
            GSCalendarCell *c = [[GSCalendarCell alloc] initWithFrame:CGRectZero];
            c.tag = i;
            UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapCell:)];
            [c addGestureRecognizer:t];
            [self addSubview:c]; [_cells addObject:c];
        }
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat left = 10, gap = 2;
    CGFloat colW = (w - left * 2) / 7.0;
    for (NSInteger i = 0; i < 7; i++) _weekLabels[i].frame = CGRectMake(left + i * colW, 13, colW, 16);
    CGFloat top = 32;
    CGFloat cellH = (h - top - 8) / 6.0;
    for (NSInteger i = 0; i < 42; i++) {
        NSInteger row = i / 7, col = i % 7;
        _cells[i].frame = CGRectMake(left + col * colW + gap, top + row * cellH + 1, colW - gap * 2, cellH - 2);
    }
}
- (void)reload {
    NSInteger weekStart = [[GSStore shared].settings[@"weekStart"] integerValue];
    NSString *classDisplay = [GSStore shared].settings[@"classDisplay"] ?: @"icon";
    NSArray *names = weekStart == 0 ? @[@"日", @"一", @"二", @"三", @"四", @"五", @"六"] : @[@"一", @"二", @"三", @"四", @"五", @"六", @"日"];
    for (NSInteger i = 0; i < 7; i++) _weekLabels[i].text = names[i];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *firstC = [[NSDateComponents alloc] init]; firstC.year = self.year; firstC.month = self.month; firstC.day = 1;
    NSDate *first = [cal dateFromComponents:firstC];
    NSInteger weekday = [cal component:NSCalendarUnitWeekday fromDate:first];
    NSInteger lead = (weekday - 1 - weekStart + 7) % 7;
    NSInteger total = GSDaysInMonth(self.year, self.month);
    NSInteger payday = [[GSStore shared].settings[@"payday"] integerValue];
    if (payday < 0 || payday > 31) payday = 0;
    NSInteger paydayDay = payday > 0 ? MIN(payday, total) : 0;
    NSString *today = GSTodayKey();
    for (NSInteger i = 0; i < 42; i++) {
        NSInteger dayNum = i - lead + 1;
        NSDate *d;
        BOOL inMonth = (dayNum >= 1 && dayNum <= total);
        if (inMonth) {
            NSDateComponents *c = [[NSDateComponents alloc] init]; c.year = self.year; c.month = self.month; c.day = dayNum;
            d = [cal dateFromComponents:c];
        } else {
            NSInteger diff = dayNum < 1 ? dayNum - 1 : dayNum - total;
            NSDateComponents *c = [[NSDateComponents alloc] init]; c.year = self.year; c.month = self.month; c.day = dayNum;
            d = [cal dateFromComponents:c];
            if (dayNum < 1) d = [cal dateByAddingUnit:NSCalendarUnitDay value:dayNum - 1 toDate:first options:0];
            else d = [cal dateByAddingUnit:NSCalendarUnitDay value:diff toDate:[cal dateByAddingUnit:NSCalendarUnitDay value:total - 1 toDate:first options:0] options:0];
        }
        NSString *key = GSKeyFromDate(d);
        GSCalendarCell *cell = _cells[i];
        cell.dateKey = key; cell.inMonth = inMonth;
        cell.dayLabel.text = [NSString stringWithFormat:@"%ld", (long)[cal component:NSCalendarUnitDay fromDate:d]];
        BOOL showLunar = [GSStore shared].settings[@"showLunar"] == nil || [[GSStore shared].settings[@"showLunar"] boolValue];
        cell.lunarLabel.text = showLunar ? GSLunarDay(d) : @"";
        NSDictionary *rec = [[GSStore shared] recordForDate:key];
        NSString *plan = [[GSStore shared] planForDate:key];
        NSString *clsId = rec[@"classId"] ?: plan;
        NSDictionary *cls = clsId ? [[GSStore shared] classWithId:clsId] : nil;
        cell.badgeLabel.text = rec ? [[GSStore shared] daySummary:rec] : @"";
        cell.badgeLabel.hidden = !rec;
        NSString *kind = GSDayKind(key);
        BOOL paydayCell = inMonth && dayNum == paydayDay;
        cell.kindLabel.text = paydayCell ? @"薪" : ([kind isEqual:@"jj"] ? @"节" : [kind isEqual:@"zm"] ? @"休" : @"");
        cell.kindLabel.textColor = paydayCell ? GSColorHex(@"#B06A00") : ([kind isEqual:@"jj"] ? GSColorHex(@"#B42318") : GSColorHex(@"#B45309"));
        cell.kindLabel.hidden = !paydayCell && ([kind isEqual:@"zb"] || !inMonth);
        cell.dot.hidden = YES;
        BOOL sel = [key isEqual:self.selectedDate] && inMonth;
        cell.selected = sel;
        NSString *className = cls[@"name"] ?: @"";
        BOOL dayShift = [className containsString:@"白"] || [className containsString:@"早"];
        BOOL nightShift = [className containsString:@"中"] || [className containsString:@"晚"] || [className containsString:@"夜"];
        BOOL showShift = cls && inMonth && ![classDisplay isEqual:@"hide"];
        cell.shiftPill.hidden = !showShift;
        cell.shiftPill.backgroundColor = UIColor.clearColor;
        cell.layer.borderWidth = 0;
        cell.backgroundColor = UIColor.clearColor;
        if (showShift) {
            UIColor *cc = dayShift ? GSColorHex(@"#B45309") : (nightShift ? GSColorHex(@"#1E3B8A") : GSColorHex(@"#475467"));
            if ([classDisplay isEqual:@"text"]) {
                cell.shiftIcon.hidden = YES; cell.shiftLabel.hidden = NO;
                cell.shiftLabel.text = className;
                cell.shiftLabel.textColor = cc;
            } else {
                cell.shiftIcon.hidden = NO; cell.shiftLabel.hidden = YES;
                cell.shiftIcon.image = GSIcon(dayShift ? @"sunrise.fill" : nightShift ? @"moon.stars.fill" : @"briefcase.fill", nightShift ? 7 : 8);
                cell.shiftIcon.tintColor = cc;
            }
        } else {
            cell.shiftIcon.hidden = YES;
            cell.shiftLabel.hidden = YES;
        }
        BOOL showLine = inMonth && (rec != nil || paydayCell || [key isEqual:today]);
        cell.todayLine.hidden = !showLine;
        if (sel) {
            cell.backgroundColor = GSThemeColor();
            cell.layer.shadowColor = GSThemeColor().CGColor;
            cell.layer.shadowOpacity = .28; cell.layer.shadowRadius = 8; cell.layer.shadowOffset = CGSizeMake(0, 4);
            cell.layer.borderWidth = 1;
            cell.layer.borderColor = [UIColor colorWithWhite:1 alpha:.32].CGColor;
            cell.dayLabel.textColor = paydayCell ? GSColorHex(@"#FFE08A") : UIColor.whiteColor;
            cell.lunarLabel.textColor = paydayCell ? GSColorHex(@"#FFE08A") : [UIColor colorWithWhite:1 alpha:.92];
            cell.badgeLabel.textColor = paydayCell ? GSColorHex(@"#FFE08A") : UIColor.whiteColor;
            cell.kindLabel.textColor = paydayCell ? GSColorHex(@"#FFE08A") : UIColor.whiteColor;
            cell.todayLine.backgroundColor = paydayCell ? GSColorHex(@"#FFE08A") : UIColor.whiteColor;
            if (showShift) {
                cell.shiftIcon.tintColor = UIColor.whiteColor;
                cell.shiftLabel.textColor = UIColor.whiteColor;
            }
        } else {
            cell.layer.shadowOpacity = 0;
            cell.dayLabel.textColor = paydayCell ? GSColorHex(@"#D99A00") : (inMonth ? GSColorHex(@"#101828") : GSColorHex(@"#C9D0DA"));
            cell.lunarLabel.textColor = paydayCell ? GSColorHex(@"#D99A00") : (inMonth ? GSColorHex(@"#5D6B82") : GSColorHex(@"#C9D0DA"));
            cell.badgeLabel.textColor = paydayCell ? GSColorHex(@"#D99A00") : GSThemeColor();
            cell.todayLine.backgroundColor = paydayCell ? GSColorHex(@"#D99A00") : GSThemeColor();
        }
        cell.dayLabel.alpha = inMonth ? 1 : .55;
        cell.lunarLabel.alpha = inMonth ? 1 : .55;
        cell.badgeLabel.alpha = inMonth ? 1 : .55;
        cell.shiftPill.alpha = inMonth ? 1 : .55;
        if (!inMonth) {
            cell.dayLabel.text = @"";
            cell.lunarLabel.text = @"";
            cell.badgeLabel.text = @"";
            cell.badgeLabel.hidden = YES;
            cell.kindLabel.hidden = YES;
            cell.shiftPill.hidden = YES;
            cell.todayLine.hidden = YES;
            cell.backgroundColor = UIColor.clearColor;
        }
        [cell setNeedsLayout];
    }
}
- (void)tapCell:(UITapGestureRecognizer *)g {
    GSCalendarCell *c = (GSCalendarCell *)g.view;
    if (!c.inMonth || c.dateKey.length == 0) return;
    GSHaptic();
    [UIView animateWithDuration:0.10 animations:^{ c.transform = CGAffineTransformMakeScale(0.92, 0.92); }];
    [UIView animateWithDuration:0.34 delay:0.08 usingSpringWithDamping:0.55 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{ c.transform = CGAffineTransformIdentity; } completion:nil];
    if (self.onSelect) self.onSelect(c.dateKey);
}
@end
