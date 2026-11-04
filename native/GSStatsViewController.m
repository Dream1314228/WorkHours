#import "GSStatsViewController.h"
#import "GSComponents.h"
#import "GSStore.h"
#import "GSExtrasViewController.h"

@interface GSStatsViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *statusBg;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *titleLabel, *periodLabel, *monthLabel;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, assign) NSInteger year, month;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight, *statusHeight, *titleTop;
@property (nonatomic, assign) BOOL statusDark;
@end
@implementation GSStatsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
    NSDate *d = [NSDate date];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    self.year = [cal component:NSCalendarUnitYear fromDate:d];
    self.month = [cal component:NSCalendarUnitMonth fromDate:d];
    self.scroll = [[UIScrollView alloc] init];
    self.scroll.backgroundColor = UIColor.clearColor;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0, 120, 0);
    [self.view addSubview:self.scroll];
    self.statusBg = [[UIView alloc] init];
    self.statusBg.backgroundColor = UIColor.clearColor;
    self.statusBg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusBg];
    self.header = [[GSGradientView alloc] init];
    self.header.colors = @[GSThemeColor(), GSThemeDarkColor()];
    self.header.translatesAutoresizingMaskIntoConstraints = NO;
    GSAddHeaderOrbs(self.header);
    GSApplyHeaderCorners(self.header);
    [self.scroll addSubview:self.header];
    self.titleLabel = GSLabel(@"统计", GSFont(28, UIFontWeightBold), UIColor.whiteColor);
    self.periodLabel = GSLabel(@"", GSFont(12, UIFontWeightRegular), [UIColor colorWithWhite:1 alpha:.92]);
    self.monthLabel = GSLabel(@"", GSFont(18, UIFontWeightBold), UIColor.whiteColor);
    for (UILabel *l in @[self.titleLabel, self.periodLabel, self.monthLabel]) { l.translatesAutoresizingMaskIntoConstraints = NO; [self.header addSubview:l]; }
    UIButton *prev = GSIconButton(@"chevron.left", UIColor.whiteColor, 18);
    UIButton *next = GSIconButton(@"chevron.right", UIColor.whiteColor, 18);
    prev.translatesAutoresizingMaskIntoConstraints = NO; next.translatesAutoresizingMaskIntoConstraints = NO;
    [prev addTarget:self action:@selector(prevMonth) forControlEvents:UIControlEventTouchUpInside];
    [next addTarget:self action:@selector(nextMonth) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:prev]; [self.header addSubview:next];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 14;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    self.statusBg.hidden = YES;
    self.scroll.delegate = self;
    self.statusHeight = [self.statusBg.heightAnchor constraintEqualToConstant:64];
    self.headerHeight = [self.header.heightAnchor constraintEqualToConstant:160];
    self.titleTop = [self.titleLabel.topAnchor constraintEqualToAnchor:self.header.topAnchor constant:72];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.statusBg.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.statusBg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.statusBg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.statusHeight,
        [self.header.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor],
        [self.header.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor],
        [self.header.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor],
        [self.header.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor],
        self.headerHeight,
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        self.titleTop,
        [self.periodLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.periodLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2],
        [self.monthLabel.topAnchor constraintEqualToAnchor:self.titleLabel.topAnchor constant:2],
        [next.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [next.centerYAnchor constraintEqualToAnchor:self.monthLabel.centerYAnchor],
        [self.monthLabel.trailingAnchor constraintEqualToAnchor:next.leadingAnchor constant:-8],
        [prev.trailingAnchor constraintEqualToAnchor:self.monthLabel.leadingAnchor constant:-8],
        [prev.centerYAnchor constraintEqualToAnchor:self.monthLabel.centerYAnchor],
        [prev.widthAnchor constraintEqualToConstant:30], [prev.heightAnchor constraintEqualToConstant:30],
        [next.widthAnchor constraintEqualToConstant:30], [next.heightAnchor constraintEqualToConstant:30],
        [self.stack.topAnchor constraintEqualToAnchor:self.header.bottomAnchor constant:16],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-120]
    ]];
    [self.view bringSubviewToFront:self.statusBg];
    [self reload];
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    CGFloat top = self.view.safeAreaInsets.top;
    self.statusHeight.constant = top;
    self.headerHeight.constant = top + 100;
    self.titleTop.constant = top + 14;
    self.header.startY = top / MAX(1, self.headerHeight.constant);
    [self.header layoutIfNeeded];
    [self updateStatusStyle];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; [self updateStatusStyle]; }
- (UIStatusBarStyle)preferredStatusBarStyle { return self.statusDark ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent; }
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { [self updateStatusStyle]; }
- (void)updateStatusStyle {
    CGFloat threshold = MAX(0, self.headerHeight.constant - self.view.safeAreaInsets.top);
    BOOL dark = self.scroll.contentOffset.y > threshold;
    if (dark != _statusDark) { _statusDark = dark; [self setNeedsStatusBarAppearanceUpdate]; [self.parentViewController setNeedsStatusBarAppearanceUpdate]; }
}
- (void)prevMonth { [self changeMonth:-1]; }
- (void)nextMonth { [self changeMonth:1]; }
- (void)changeMonth:(NSInteger)delta {
    NSDateComponents *c = GSMonthAdd(self.year, self.month, delta);
    self.year = c.year; self.month = c.month;
    GSHaptic(); [self reload];
}
- (GSCardView *)cardWithViews:(NSArray<UIView *> *)views spacing:(CGFloat)spacing {
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *v = GSStack(views, UILayoutConstraintAxisVertical, spacing);
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18]
    ]];
    return card;
}
- (UILabel *)cardTitle:(NSString *)text {
    return GSLabel(text, GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
}
- (UIView *)statBox:(NSString *)value label:(NSString *)label color:(UIColor *)color {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = GSColorHex(@"#F2F6FF"); v.layer.cornerRadius = 16;
    UILabel *b = GSLabel(value, GSFont(18, UIFontWeightBold), color);
    UILabel *l = GSLabel(label, GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    b.translatesAutoresizingMaskIntoConstraints = NO; l.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:b]; [v addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [b.topAnchor constraintEqualToAnchor:v.topAnchor constant:10], [b.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:12], [b.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-12],
        [l.topAnchor constraintEqualToAnchor:b.bottomAnchor constant:2], [l.leadingAnchor constraintEqualToAnchor:b.leadingAnchor], [l.trailingAnchor constraintEqualToAnchor:b.trailingAnchor],
        [v.heightAnchor constraintEqualToConstant:62]
    ]];
    return v;
}
- (void)reload {
    NSDictionary *st = [[GSStore shared] monthStats:self.year month:self.month usePeriod:YES];
    self.monthLabel.text = [NSString stringWithFormat:@"%ld月", (long)self.month];
    self.periodLabel.text = [NSString stringWithFormat:@"%ld年 · %@", (long)self.year, st[@"label"]];
    for (UIView *v in self.stack.arrangedSubviews) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
    UILabel *big = GSLabel(GSMoney([st[@"pay"] doubleValue]), GSFont(31, UIFontWeightBold), GSColorHex(@"#B45309"));
    UILabel *cap = GSLabel(@"本期合计", GSFont(11, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UIStackView *sumTop = GSStack(@[big, cap], UILayoutConstraintAxisVertical, 0);
    UIView *b1 = [self statBox:GSNum([st[@"hours"] doubleValue]) label:@"总工时" color:GSThemeColor()];
    UIView *b2 = [self statBox:GSNum([st[@"days"] doubleValue]) label:@"出勤天数" color:GSColorHex(@"#101828")];
    UIView *b3 = [self statBox:GSMoney([st[@"bonus"] doubleValue]) label:@"补贴" color:GSColorHex(@"#067647")];
    UIView *b4 = [self statBox:GSMoney([st[@"deduct"] doubleValue]) label:@"扣款" color:GSColorHex(@"#B42318")];
    double otHours = [st[@"jb"] doubleValue] + [st[@"zm"] doubleValue] + [st[@"jj"] doubleValue];
    UIView *b5 = [self statBox:[NSString stringWithFormat:@"%.1f", [st[@"avg"] doubleValue]] label:@"平均时薪" color:GSThemeColor()];
    UIView *b6 = [self statBox:[NSString stringWithFormat:@"%@H", GSNum(otHours)] label:@"加班/周末/节假" color:GSColorHex(@"#B54708")];
    UIStackView *row1 = GSStack(@[b1, b2], UILayoutConstraintAxisHorizontal, 8); row1.distribution = UIStackViewDistributionFillEqually;
    UIStackView *row2 = GSStack(@[b3, b4], UILayoutConstraintAxisHorizontal, 8); row2.distribution = UIStackViewDistributionFillEqually;
    UIStackView *row3 = GSStack(@[b5, b6], UILayoutConstraintAxisHorizontal, 8); row3.distribution = UIStackViewDistributionFillEqually;
    GSCardView *summary = [self cardWithViews:@[sumTop, row1, row2, row3] spacing:12];
    [self.stack addArrangedSubview:summary];

    double workPay = [st[@"pay"] doubleValue] - [st[@"bonus"] doubleValue] + [st[@"deduct"] doubleValue];
    NSMutableArray *incomeRows = [NSMutableArray array];
    [incomeRows addObject:[self cardTitle:@"本期收入构成"]];
    UILabel *workLine = GSLabel([NSString stringWithFormat:@"工时工资  %@", GSMoney(workPay)], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
    UILabel *bonusLine = GSLabel([NSString stringWithFormat:@"补贴  +%@", GSMoney([st[@"bonus"] doubleValue])], GSFont(12, UIFontWeightRegular), GSColorHex(@"#067647"));
    UILabel *deductLine = GSLabel([NSString stringWithFormat:@"扣款  -%@", GSMoney([st[@"deduct"] doubleValue])], GSFont(12, UIFontWeightRegular), GSColorHex(@"#B42318"));
    UILabel *netLine = GSLabel([NSString stringWithFormat:@"实发  %@", GSMoney([st[@"pay"] doubleValue])], GSFont(14, UIFontWeightBold), GSThemeColor());
    [incomeRows addObject:GSStack(@[workLine, bonusLine], UILayoutConstraintAxisHorizontal, 12)];
    [incomeRows addObject:GSStack(@[deductLine, netLine], UILayoutConstraintAxisHorizontal, 12)];
    [self.stack addArrangedSubview:[self cardWithViews:incomeRows spacing:8]];

    double maxH = MAX(1, MAX(MAX([st[@"zb"] doubleValue], [st[@"jb"] doubleValue]), MAX([st[@"zm"] doubleValue], [st[@"jj"] doubleValue])));
    NSMutableArray *typeRows = [NSMutableArray array];
    [typeRows addObject:[self cardTitle:@"工时构成"]];
    NSArray *names = @[@"正班", @"加班", @"周末", @"节假"];
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj"];
    for (NSInteger i = 0; i < 4; i++) {
        UILabel *n = GSLabel(names[i], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
        [n.widthAnchor constraintEqualToConstant:34].active = YES;
        UIProgressView *p = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        p.progressTintColor = GSThemeColor(); p.trackTintColor = GSColorHex(@"#EEF3FA");
        p.progress = [st[keys[i]] doubleValue] / maxH;
        p.layer.cornerRadius = 4; p.clipsToBounds = YES;
        [p.heightAnchor constraintEqualToConstant:8].active = YES;
        UILabel *v = GSLabel([NSString stringWithFormat:@"%@H", GSNum([st[keys[i]] doubleValue])], GSFont(12, UIFontWeightSemibold), GSColorHex(@"#101828"));
        v.textAlignment = NSTextAlignmentRight; [v.widthAnchor constraintEqualToConstant:48].active = YES;
        UIStackView *row = GSStack(@[n, p, v], UILayoutConstraintAxisHorizontal, 10);
        row.alignment = UIStackViewAlignmentCenter;
        [typeRows addObject:row];
    }
    [self.stack addArrangedSubview:[self cardWithViews:typeRows spacing:9]];

    NSMutableArray *daily = [NSMutableArray array];
    UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];
    [copy setTitle:@"复制报表" forState:UIControlStateNormal]; copy.titleLabel.font = GSFont(12, UIFontWeightMedium);
    [copy addTarget:self action:@selector(copyReport) forControlEvents:UIControlEventTouchUpInside];
    UILabel *dt = [self cardTitle:@"每日明细"];
    UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *dh = GSStack(@[dt, sp, copy], UILayoutConstraintAxisHorizontal, 8);
    [daily addObject:dh];
    NSArray *keys2 = [[GSStore shared] dailyKeysForYear:self.year month:self.month];
    if (keys2.count == 0) {
        [daily addObject:GSLabel(@"本月还没有记录", GSFont(13, UIFontWeightRegular), GSColorHex(@"#5D6B82"))];
    } else {
        for (NSString *k in keys2) {
            NSDictionary *r = [[GSStore shared] recordForDate:k];
            UILabel *dd = GSLabel([k substringFromIndex:5], GSFont(12, UIFontWeightSemibold), GSColorHex(@"#101828"));
            [dd.widthAnchor constraintEqualToConstant:42].active = YES;
            NSDictionary *c = [[GSStore shared] classWithId:r[@"classId"]];
            UILabel *tt = GSLabel([NSString stringWithFormat:@"%@ · %@", c[@"name"] ?: @"", [[GSStore shared] daySummary:r]], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
            UILabel *mm = GSLabel(GSMoney([[GSStore shared] dayPay:r]), GSFont(12, UIFontWeightBold), GSColorHex(@"#B45309"));
            mm.textAlignment = NSTextAlignmentRight;
            UIStackView *row = GSStack(@[dd, tt, mm], UILayoutConstraintAxisHorizontal, 8);
            [daily addObject:row];
        }
    }
    [self.stack addArrangedSubview:[self cardWithViews:daily spacing:8]];

    NSMutableArray *extraViews = [NSMutableArray array];
    UILabel *et = [self cardTitle:@"本期补扣明细"];
    UIButton *manage = [UIButton buttonWithType:UIButtonTypeSystem];
    [manage setTitle:@"管理" forState:UIControlStateNormal]; manage.titleLabel.font = GSFont(13, UIFontWeightSemibold);
    [manage addTarget:self action:@selector(openExtras) forControlEvents:UIControlEventTouchUpInside];
    UIView *esp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *eh = GSStack(@[et, esp, manage], UILayoutConstraintAxisHorizontal, 8);
    [extraViews addObject:eh];
    NSArray *bs = [[GSStore shared] extrasForKind:@"bonus" year:self.year month:self.month];
    NSArray *ds = [[GSStore shared] extrasForKind:@"deduct" year:self.year month:self.month];
    double bsSum = 0, dsSum = 0;
    for (NSDictionary *b in bs) bsSum += [b[@"money"] doubleValue];
    for (NSDictionary *b in ds) dsSum += [b[@"money"] doubleValue];
    UILabel *sum = GSLabel([NSString stringWithFormat:@"月度补贴 +%@ · %ld 笔    月度扣款 -%@ · %ld 笔", GSMoney(bsSum), (long)bs.count, GSMoney(dsSum), (long)ds.count], GSFont(11, UIFontWeightRegular), GSColorHex(@"#667085"));
    sum.numberOfLines = 0;
    [extraViews addObject:sum];
    NSArray *kinds = @[@"bonus", @"deduct"];
    for (NSString *kind in kinds) {
        BOOL isBonus = [kind isEqual:@"bonus"];
        NSArray *items = isBonus ? bs : ds;
        double total = 0;
        for (NSDictionary *b in items) total += [b[@"money"] doubleValue];
        UILabel *section = GSLabel([NSString stringWithFormat:@"%@ · %ld 笔 · %@", isBonus ? @"补贴" : @"扣款", (long)items.count, isBonus ? [NSString stringWithFormat:@"+%@", GSMoney(total)] : [NSString stringWithFormat:@"-%@", GSMoney(total)]], GSFont(12, UIFontWeightSemibold), isBonus ? GSColorHex(@"#067647") : GSColorHex(@"#B42318"));
        [extraViews addObject:section];
        if (items.count == 0) {
            [extraViews addObject:GSLabel(isBonus ? @"本期没有补贴" : @"本期没有扣款", GSFont(11, UIFontWeightRegular), GSColorHex(@"#98A2B3"))];
            continue;
        }
        for (NSDictionary *b in items) {
            NSString *name = [b[@"name"] isKindOfClass:[NSString class]] ? b[@"name"] : (isBonus ? @"补贴" : @"扣款");
            NSString *note = [b[@"note"] isKindOfClass:[NSString class]] ? b[@"note"] : @"";
            BOOL autoImport = [b[@"auto"] isKindOfClass:[NSNumber class]] && [b[@"auto"] boolValue];
            NSString *source = autoImport ? @"自动导入" : (note.length ? note : @"手动添加");
            UILabel *n = GSLabel(name, GSFont(12, UIFontWeightSemibold), GSColorHex(@"#344054"));
            UILabel *src = GSLabel(source, GSFont(9, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
            UIStackView *left = GSStack(@[n, src], UILayoutConstraintAxisVertical, 1);
            UILabel *m = GSLabel([NSString stringWithFormat:@"%@%@", isBonus ? @"+" : @"-", GSMoney([b[@"money"] doubleValue])], GSFont(12, UIFontWeightBold), isBonus ? GSColorHex(@"#067647") : GSColorHex(@"#B42318"));
            [extraViews addObject:GSStack(@[left, m], UILayoutConstraintAxisHorizontal, 8)];
        }
    }
    NSMutableDictionary *dailyGroups = [NSMutableDictionary dictionary];
    for (NSString *date in [[GSStore shared] dailyKeysForYear:self.year month:self.month]) {
        NSDictionary *rec = [[GSStore shared] recordForDate:date];
        id rawBT = rec[@"bt"];
        if (![rawBT isKindOfClass:[NSArray class]]) continue;
        for (NSDictionary *b in rawBT) {
            if (![b isKindOfClass:[NSDictionary class]]) continue;
            double bm = [b[@"money"] doubleValue];
            if (fabs(bm) < .001) continue;
            NSString *name = [b[@"name"] isKindOfClass:[NSString class]] ? b[@"name"] : @"补扣";
            NSString *key = [NSString stringWithFormat:@"%@|%d", name, bm > 0 ? 1 : 0];
            NSMutableDictionary *g = dailyGroups[key];
            if (!g) { g = [@{@"name":name, @"count":@0, @"sum":@0} mutableCopy]; dailyGroups[key] = g; }
            g[@"count"] = @([g[@"count"] integerValue] + 1);
            g[@"sum"] = @([g[@"sum"] doubleValue] + bm);
        }
    }
    if (dailyGroups.count > 0) {
        [extraViews addObject:[self cardTitle:@"每日补扣汇总"]];
        for (NSString *key in [dailyGroups.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *g = dailyGroups[key];
            double sum = [g[@"sum"] doubleValue];
            UILabel *n = GSLabel([NSString stringWithFormat:@"每日 · %@ ×%ld", g[@"name"], (long)[g[@"count"] integerValue]], GSFont(11, UIFontWeightRegular), GSColorHex(@"#475467"));
            UILabel *m = GSLabel([NSString stringWithFormat:@"%@%@", sum > 0 ? @"+" : @"-", GSMoney(fabs(sum))], GSFont(11, UIFontWeightBold), sum > 0 ? GSColorHex(@"#067647") : GSColorHex(@"#B42318"));
            [extraViews addObject:GSStack(@[n, m], UILayoutConstraintAxisHorizontal, 8)];
        }
    }
    [extraViews addObject:GSLabel(@"月度台账和每日补扣都会列出；上方本期总额已包含这两部分。", GSFont(9, UIFontWeightRegular), GSColorHex(@"#98A2B3"))];
    [self.stack addArrangedSubview:[self cardWithViews:extraViews spacing:8]];
    GSAnimateStack(self.stack);
}
- (void)copyReport {
    UIPasteboard.generalPasteboard.string = [[GSStore shared] reportTextForYear:self.year month:self.month];
    GSToast(@"报表已复制");
}
- (void)openExtras {
    GSExtrasViewController *e = [[GSExtrasViewController alloc] initWithYear:self.year month:self.month];
    __weak typeof(self) weakSelf = self;
    e.onChanged = ^{ [weakSelf reload]; };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:e];
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
