#import "GSScheduleViewController.h"
#import "GSComponents.h"
#import "GSCalendarView.h"
#import "GSStore.h"

@interface GSScheduleViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *statusBg;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *yearLabel, *bigPay, *subLabel;
@property (nonatomic, strong) UILabel *h1, *h2, *h3, *h4;
@property (nonatomic, strong) UISegmentedControl *seg;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, assign) NSInteger year, month;
@property (nonatomic, assign) BOOL boardView;
@property (nonatomic, copy) NSString *palette;
@property (nonatomic, copy) NSString *selectedDate;
@property (nonatomic, strong) GSCalendarView *scheduleCalendar;
@property (nonatomic, strong) NSMutableArray<UIButton *> *classChips;
@property (nonatomic, strong) UILabel *scheduleHint;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight, *statusHeight, *yearTop;
@property (nonatomic, assign) BOOL statusDark;
- (void)buildBoard:(NSDictionary *)st;
- (void)buildIncome:(NSDictionary *)st;
- (void)buildSchedule;
- (void)exportHTML;
@end
@implementation GSScheduleViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    self.year = [cal component:NSCalendarUnitYear fromDate:now];
    self.month = [cal component:NSCalendarUnitMonth fromDate:now];
    self.boardView = YES;
    self.palette = @"1";
    self.selectedDate = GSTodayKey();
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
    self.yearLabel = GSLabel(@"", GSFont(15, UIFontWeightBold), UIColor.whiteColor);
    self.bigPay = GSLabel(@"", GSFont(45, UIFontWeightBold), UIColor.whiteColor);
    self.subLabel = GSLabel(@"", GSFont(11, UIFontWeightRegular), [UIColor colorWithWhite:1 alpha:.92]);
    UILabel *annual = GSLabel(@"ANNUAL", GSFont(9, UIFontWeightSemibold), [UIColor colorWithWhite:1 alpha:.92]);
    annual.layer.borderWidth = 1; annual.layer.borderColor = [UIColor colorWithWhite:1 alpha:.25].CGColor;
    annual.layer.cornerRadius = 10; annual.clipsToBounds = YES; annual.textAlignment = NSTextAlignmentCenter;
    for (UILabel *l in @[self.yearLabel, self.bigPay, self.subLabel, annual]) { l.translatesAutoresizingMaskIntoConstraints = NO; [self.header addSubview:l]; }
    UIButton *prev = GSIconButton(@"chevron.left", UIColor.whiteColor, 15);
    UIButton *next = GSIconButton(@"chevron.right", UIColor.whiteColor, 15);
    prev.translatesAutoresizingMaskIntoConstraints = NO; next.translatesAutoresizingMaskIntoConstraints = NO;
    [prev addTarget:self action:@selector(prevYear) forControlEvents:UIControlEventTouchUpInside];
    [next addTarget:self action:@selector(nextYear) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:prev]; [self.header addSubview:next];
    UIView *stats = [[UIView alloc] init];
    stats.backgroundColor = [UIColor colorWithWhite:0 alpha:.09]; stats.layer.cornerRadius = 16;
    stats.layer.borderWidth = 1; stats.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    stats.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:stats];
    NSMutableArray *boxes = [NSMutableArray array];
    NSMutableArray *vals = [NSMutableArray array];
    NSArray *titles = @[@"总工时", @"出勤", @"平均时薪", @"加班"];
    for (NSInteger i = 0; i < 4; i++) {
        UILabel *v = GSLabel(@"", GSFont(17, UIFontWeightBold), UIColor.whiteColor); v.textAlignment = NSTextAlignmentCenter;
        UILabel *t = GSLabel(titles[i], GSFont(9, UIFontWeightRegular), [UIColor colorWithWhite:1 alpha:.92]); t.textAlignment = NSTextAlignmentCenter;
        [boxes addObject:GSStack(@[v, t], UILayoutConstraintAxisVertical, 2)]; [vals addObject:v];
    }
    self.h1 = vals[0]; self.h2 = vals[1]; self.h3 = vals[2]; self.h4 = vals[3];
    UIStackView *statStack = GSStack(boxes, UILayoutConstraintAxisHorizontal, 0);
    statStack.distribution = UIStackViewDistributionFillEqually;
    statStack.translatesAutoresizingMaskIntoConstraints = NO; [stats addSubview:statStack];
    self.seg = [[UISegmentedControl alloc] initWithItems:@[@"排班", @"看板"]];
    self.seg.selectedSegmentIndex = 1;
    self.seg.selectedSegmentTintColor = UIColor.whiteColor;
    [self.seg setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:1 alpha:.95], NSFontAttributeName:GSFont(13, UIFontWeightSemibold)} forState:UIControlStateNormal];
    [self.seg setTitleTextAttributes:@{NSForegroundColorAttributeName:GSThemeColor(), NSFontAttributeName:GSFont(13, UIFontWeightSemibold)} forState:UIControlStateSelected];
    self.seg.backgroundColor = [UIColor colorWithWhite:0 alpha:.10]; self.seg.layer.cornerRadius = 12; self.seg.clipsToBounds = YES;
    [self.seg addTarget:self action:@selector(viewChanged) forControlEvents:UIControlEventValueChanged];
    self.seg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:self.seg];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 14;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    self.statusBg.hidden = YES;
    self.scroll.delegate = self;
    self.statusHeight = [self.statusBg.heightAnchor constraintEqualToConstant:64];
    self.headerHeight = [self.header.heightAnchor constraintEqualToConstant:330];
    self.yearTop = [self.yearLabel.topAnchor constraintEqualToAnchor:self.header.topAnchor constant:72];
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
        [self.yearLabel.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:56],
        self.yearTop,
        [prev.trailingAnchor constraintEqualToAnchor:self.yearLabel.leadingAnchor constant:-8],
        [prev.centerYAnchor constraintEqualToAnchor:self.yearLabel.centerYAnchor],
        [prev.widthAnchor constraintEqualToConstant:30], [prev.heightAnchor constraintEqualToConstant:30],
        [next.leadingAnchor constraintEqualToAnchor:self.yearLabel.trailingAnchor constant:8],
        [next.centerYAnchor constraintEqualToAnchor:self.yearLabel.centerYAnchor],
        [next.widthAnchor constraintEqualToConstant:30], [next.heightAnchor constraintEqualToConstant:30],
        [annual.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [annual.centerYAnchor constraintEqualToAnchor:self.yearLabel.centerYAnchor],
        [annual.widthAnchor constraintEqualToConstant:62], [annual.heightAnchor constraintEqualToConstant:22],
        [self.bigPay.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [self.bigPay.topAnchor constraintEqualToAnchor:self.yearLabel.bottomAnchor constant:14],
        [self.subLabel.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [self.subLabel.topAnchor constraintEqualToAnchor:self.bigPay.bottomAnchor constant:4],
        [stats.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [stats.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [stats.topAnchor constraintEqualToAnchor:self.subLabel.bottomAnchor constant:14],
        [stats.heightAnchor constraintEqualToConstant:62],
        [statStack.leadingAnchor constraintEqualToAnchor:stats.leadingAnchor constant:4],
        [statStack.trailingAnchor constraintEqualToAnchor:stats.trailingAnchor constant:-4],
        [statStack.centerYAnchor constraintEqualToAnchor:stats.centerYAnchor],
        [self.seg.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [self.seg.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [self.seg.topAnchor constraintEqualToAnchor:stats.bottomAnchor constant:14],
        [self.seg.heightAnchor constraintEqualToConstant:40],
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
    self.headerHeight.constant = top + 258;
    self.yearTop.constant = top + 14;
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
- (void)prevYear { self.year--; [self reload]; }
- (void)nextYear { self.year++; [self reload]; }
- (void)viewChanged { self.boardView = self.seg.selectedSegmentIndex == 1; [self reload]; }
- (GSCardView *)cardWithTitle:(NSString *)title content:(UIView *)content {
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *v = [[UIStackView alloc] init];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 12; v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    UILabel *t = GSLabel(title, GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
    [v addArrangedSubview:t];
    if (content) [v addArrangedSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18]
    ]];
    return card;
}
- (void)reload {
    NSDictionary *st = [[GSStore shared] yearStats:self.year];
    self.yearLabel.text = [NSString stringWithFormat:@"%ld 年度", (long)self.year];
    self.bigPay.text = [NSString stringWithFormat:@"¥%@", GSNum([st[@"pay"] doubleValue])];
    self.subLabel.text = [NSString stringWithFormat:@"时薪 %.0f元  ·  %ld年 %@ 天出勤", [st[@"avg"] doubleValue], (long)self.year, GSNum([st[@"days"] doubleValue])];
    self.h1.text = [NSString stringWithFormat:@"%@H", GSNum([st[@"hours"] doubleValue])];
    self.h2.text = [NSString stringWithFormat:@"%@天", GSNum([st[@"days"] doubleValue])];
    self.h3.text = [NSString stringWithFormat:@"%.0f元", [st[@"avg"] doubleValue]];
    self.h4.text = [NSString stringWithFormat:@"%@H", GSNum([st[@"ot"] doubleValue])];
    self.seg.selectedSegmentIndex = self.boardView ? 1 : 0;
    for (UIView *v in self.stack.arrangedSubviews) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
    if (self.boardView) [self buildBoard:st]; else [self buildSchedule];
}
- (void)buildBoard:(NSDictionary *)st {
    UIButton *export = [UIButton buttonWithType:UIButtonTypeSystem];
    [export setTitle:@"导出 HTML 报表" forState:UIControlStateNormal];
    [export setImage:GSIcon(@"square.and.arrow.up", 14) forState:UIControlStateNormal];
    export.tintColor = GSThemeColor();
    export.titleLabel.font = GSFont(13, UIFontWeightSemibold);
    [export setTitleColor:GSThemeColor() forState:UIControlStateNormal];
    export.backgroundColor = UIColor.whiteColor;
    export.layer.cornerRadius = 14;
    [export.heightAnchor constraintEqualToConstant:44].active = YES;
    [export addTarget:self action:@selector(exportHTML) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:export];
    NSArray *months = st[@"months"];
    double totalH = [st[@"hours"] doubleValue], totalDays = [st[@"days"] doubleValue];
    double totalOT = [st[@"ot"] doubleValue], totalPay = [st[@"pay"] doubleValue];
    double totalBonus = [st[@"bonus"] doubleValue], totalDeduct = [st[@"deduct"] doubleValue];
    double weekendH = 0, holidayH = 0, normalH = 0, overtimeH = 0, bestH = 0, maxPay = 0, minPay = 0;
    NSInteger activeMonths = 0, bestMonth = 0, bestPayMonth = 0, lowestPayMonth = 0;
    for (NSInteger i = 0; i < (NSInteger)months.count; i++) {
        NSDictionary *m = months[i];
        double h = [m[@"hours"] doubleValue];
        normalH += [m[@"zb"] doubleValue];
        overtimeH += [m[@"jb"] doubleValue];
        weekendH += [m[@"zm"] doubleValue];
        holidayH += [m[@"jj"] doubleValue];
        if (h > 0) {
            activeMonths++;
            double mp = [m[@"pay"] doubleValue];
            if (bestPayMonth == 0 || mp > maxPay) { maxPay = mp; bestPayMonth = i + 1; }
            if (lowestPayMonth == 0 || mp < minPay) { minPay = mp; lowestPayMonth = i + 1; }
        }
        if (h > bestH) { bestH = h; bestMonth = i + 1; }
    }
    double avgDaily = totalDays > 0 ? totalH / totalDays : 0;
    double avgMonth = activeMonths > 0 ? totalH / activeMonths : 0;
    double avgMonthPay = activeMonths > 0 ? totalPay / activeMonths : 0;
    double otRate = totalH > 0 ? totalOT / totalH * 100.0 : 0;
    double leaveTotal = [[GSStore shared] annualLeaveTotalDays];
    double leaveUsed = [[GSStore shared] annualLeaveUsedDaysForYear:self.year];

    UIView *(^metricBox)(NSString *, NSString *, UIColor *) = ^UIView *(NSString *title, NSString *value, UIColor *color) {
        UIView *box = [[UIView alloc] init];
        box.backgroundColor = GSColorHex(@"#F7F9FC");
        box.layer.cornerRadius = 12;
        UILabel *v = GSLabel(value, GSFont(16, UIFontWeightBold), color);
        v.adjustsFontSizeToFitWidth = YES; v.minimumScaleFactor = .65;
        UILabel *t = GSLabel(title, GSFont(9, UIFontWeightRegular), GSColorHex(@"#667085"));
        v.textAlignment = NSTextAlignmentCenter; t.textAlignment = NSTextAlignmentCenter;
        UIStackView *sv = GSStack(@[v, t], UILayoutConstraintAxisVertical, 3);
        sv.translatesAutoresizingMaskIntoConstraints = NO;
        [box addSubview:sv];
        [NSLayoutConstraint activateConstraints:@[
            [sv.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],
            [sv.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
            [box.heightAnchor constraintEqualToConstant:58]
        ]];
        return box;
    };
    UIStackView *row1 = GSStack(@[
        metricBox(@"日均工时", [NSString stringWithFormat:@"%@H", GSNum(avgDaily)], GSThemeColor()),
        metricBox(@"加班占比", [NSString stringWithFormat:@"%.0f%%", otRate], GSColorHex(@"#B54708")),
        metricBox(@"有记录月份", [NSString stringWithFormat:@"%ld", (long)activeMonths], GSColorHex(@"#067647"))
    ], UILayoutConstraintAxisHorizontal, 8);
    row1.distribution = UIStackViewDistributionFillEqually;
    UIStackView *row2 = GSStack(@[
        metricBox(@"月均工时", [NSString stringWithFormat:@"%@H", GSNum(avgMonth)], GSThemeColor()),
        metricBox(@"年假使用", [NSString stringWithFormat:@"%@/%@天", GSNum(leaveUsed), GSNum(leaveTotal)], GSColorHex(@"#6941C6")),
        metricBox(@"最高月", bestMonth > 0 ? [NSString stringWithFormat:@"%ld月", (long)bestMonth] : @"—", GSColorHex(@"#B42318"))
    ], UILayoutConstraintAxisHorizontal, 8);
    row2.distribution = UIStackViewDistributionFillEqually;
    UIStackView *row3 = GSStack(@[
        metricBox(@"最高月工资", bestPayMonth > 0 ? [NSString stringWithFormat:@"%ld月 %@", (long)bestPayMonth, GSMoney(maxPay)] : @"—", GSColorHex(@"#067647")),
        metricBox(@"月均工资", GSMoney(avgMonthPay), GSThemeColor()),
        metricBox(@"最低月工资", lowestPayMonth > 0 ? [NSString stringWithFormat:@"%ld月 %@", (long)lowestPayMonth, GSMoney(minPay)] : @"—", GSColorHex(@"#B54708"))
    ], UILayoutConstraintAxisHorizontal, 8);
    row3.distribution = UIStackViewDistributionFillEqually;
    UIStackView *grid = GSStack(@[row1, row2, row3], UILayoutConstraintAxisVertical, 8);
    [self.stack addArrangedSubview:[self cardWithTitle:@"年度概览" content:grid]];

    NSArray *partNames = @[@"正班", @"加班", @"周末", @"节假"];
    NSArray *partVals = @[@(normalH), @(overtimeH), @(weekendH), @(holidayH)];
    NSArray *partColors = @[GSThemeColor(), GSColorHex(@"#D92D20"), GSColorHex(@"#F79009"), GSColorHex(@"#6941C6")];
    NSMutableArray *partRows = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) {
        double v = [partVals[i] doubleValue];
        double ratio = totalH > 0 ? v / totalH : 0;
        UILabel *name = GSLabel(partNames[i], GSFont(12, UIFontWeightSemibold), GSColorHex(@"#344054"));
        UILabel *value = GSLabel([NSString stringWithFormat:@"%@H · %.0f%%", GSNum(v), ratio * 100], GSFont(11, UIFontWeightMedium), partColors[i]);
        value.textAlignment = NSTextAlignmentRight;
        UIView *top = [[UIView alloc] init];
        [top addSubview:name]; [top addSubview:value];
        name.translatesAutoresizingMaskIntoConstraints = NO; value.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [top.heightAnchor constraintEqualToConstant:20],
            [name.leadingAnchor constraintEqualToAnchor:top.leadingAnchor], [name.centerYAnchor constraintEqualToAnchor:top.centerYAnchor],
            [value.trailingAnchor constraintEqualToAnchor:top.trailingAnchor], [value.centerYAnchor constraintEqualToAnchor:top.centerYAnchor]
        ]];
        UIView *track = [[UIView alloc] init];
        track.backgroundColor = GSColorHex(@"#EEF2F7"); track.layer.cornerRadius = 3; track.clipsToBounds = YES;
        track.translatesAutoresizingMaskIntoConstraints = NO;
        [track.heightAnchor constraintEqualToConstant:6].active = YES;
        UIView *fill = [[UIView alloc] init];
        fill.backgroundColor = partColors[i];
        fill.translatesAutoresizingMaskIntoConstraints = NO;
        [track addSubview:fill];
        [fill.widthAnchor constraintEqualToAnchor:track.widthAnchor multiplier:MAX(0, MIN(1, ratio))].active = YES;
        [NSLayoutConstraint activateConstraints:@[
            [fill.leadingAnchor constraintEqualToAnchor:track.leadingAnchor], [fill.topAnchor constraintEqualToAnchor:track.topAnchor],
            [fill.bottomAnchor constraintEqualToAnchor:track.bottomAnchor]
        ]];
        [partRows addObject:GSStack(@[top, track], UILayoutConstraintAxisVertical, 5)];
    }
    [self.stack addArrangedSubview:[self cardWithTitle:@"工时构成 · 全年" content:GSStack(partRows, UILayoutConstraintAxisVertical, 10)]];

    double maxH = 1;
    for (NSDictionary *m in months) maxH = MAX(maxH, [m[@"hours"] doubleValue]);
    NSMutableArray *cols = [NSMutableArray array];
    for (NSInteger i = 0; i < 12; i++) {
        NSDictionary *m = months[i];
        UIView *col = [[UIView alloc] init];
        col.tag = i;
        UIView *bar = [[UIView alloc] init];
        bar.backgroundColor = GSColorHex(@"#E7EDF6");
        bar.layer.cornerRadius = 5;
        bar.clipsToBounds = YES;
        UILabel *lab = GSLabel([NSString stringWithFormat:@"%ld", (long)(i + 1)], GSFont(9, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        lab.textAlignment = NSTextAlignmentCenter;
        bar.translatesAutoresizingMaskIntoConstraints = NO; lab.translatesAutoresizingMaskIntoConstraints = NO;
        [col addSubview:bar]; [col addSubview:lab];
        double total = [m[@"hours"] doubleValue];
        double normal = [m[@"zb"] doubleValue];
        double overtime = MAX(0, total - normal);
        double h = 8 + total / maxH * 118;
        UIView *normalBar = [[UIView alloc] init];
        normalBar.backgroundColor = GSThemeColor();
        normalBar.translatesAutoresizingMaskIntoConstraints = NO;
        UIView *otBar = [[UIView alloc] init];
        otBar.backgroundColor = GSColorHex(@"#D92D20");
        otBar.translatesAutoresizingMaskIntoConstraints = NO;
        [bar addSubview:normalBar]; [bar addSubview:otBar];
        double normalH = total > 0 ? h * normal / total : 0;
        double otH = total > 0 ? h - normalH : 0;
        [NSLayoutConstraint activateConstraints:@[
            [lab.bottomAnchor constraintEqualToAnchor:col.bottomAnchor],
            [lab.leadingAnchor constraintEqualToAnchor:col.leadingAnchor], [lab.trailingAnchor constraintEqualToAnchor:col.trailingAnchor],
            [lab.heightAnchor constraintEqualToConstant:12],
            [bar.bottomAnchor constraintEqualToAnchor:lab.topAnchor constant:-4],
            [bar.centerXAnchor constraintEqualToAnchor:col.centerXAnchor],
            [bar.widthAnchor constraintEqualToConstant:14],
            [bar.heightAnchor constraintEqualToConstant:MAX(4, h)],
            [normalBar.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor], [normalBar.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
            [normalBar.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
            [normalBar.heightAnchor constraintEqualToConstant:normalH],
            [otBar.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor], [otBar.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
            [otBar.bottomAnchor constraintEqualToAnchor:normalBar.topAnchor],
            [otBar.heightAnchor constraintEqualToConstant:otH],
            [col.heightAnchor constraintEqualToConstant:160]
        ]];
        [col addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapBar:)]];
        [cols addObject:col];
    }
    UIStackView *chart = GSStack(cols, UILayoutConstraintAxisHorizontal, 5);
    chart.distribution = UIStackViewDistributionFillEqually;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *chartWrap = [[UIView alloc] init];
    chartWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [chartWrap addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:chartWrap.topAnchor], [chart.leadingAnchor constraintEqualToAnchor:chartWrap.leadingAnchor],
        [chart.trailingAnchor constraintEqualToAnchor:chartWrap.trailingAnchor], [chart.bottomAnchor constraintEqualToAnchor:chartWrap.bottomAnchor],
        [chartWrap.heightAnchor constraintEqualToConstant:160]
    ]];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(7, 1)];
    UIImage *dashImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [[UIColor clearColor] setFill]; UIRectFill(CGRectMake(0, 0, 7, 1));
        [GSColorHex(@"#98A2B3") setFill]; UIRectFill(CGRectMake(0, 0, 4, 1));
    }];
    UIView *avgLine = [[UIView alloc] init];
    avgLine.backgroundColor = [UIColor colorWithPatternImage:dashImage];
    avgLine.translatesAutoresizingMaskIntoConstraints = NO;
    [chartWrap addSubview:avgLine];
    UILabel *avgLabel = GSLabel([NSString stringWithFormat:@"均值 %@H", GSNum(avgMonth)], GSFont(8, UIFontWeightMedium), GSColorHex(@"#667085"));
    avgLabel.textAlignment = NSTextAlignmentRight;
    avgLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [chartWrap addSubview:avgLabel];
    double avgRatio = maxH > 0 ? MIN(1, avgMonth / maxH) : 0;
    double avgOffset = 16 + avgRatio * 118;
    [NSLayoutConstraint activateConstraints:@[
        [avgLine.leadingAnchor constraintEqualToAnchor:chartWrap.leadingAnchor],
        [avgLine.trailingAnchor constraintEqualToAnchor:chartWrap.trailingAnchor],
        [avgLine.bottomAnchor constraintEqualToAnchor:chartWrap.bottomAnchor constant:-avgOffset],
        [avgLine.heightAnchor constraintEqualToConstant:1],
        [avgLabel.trailingAnchor constraintEqualToAnchor:chartWrap.trailingAnchor],
        [avgLabel.bottomAnchor constraintEqualToAnchor:avgLine.topAnchor constant:-1]
    ]];
    NSArray *legendColors = @[GSThemeColor(), GSColorHex(@"#D92D20")];
    NSArray *legendNames = @[@"正班工时", @"加班/周末/节假"];
    NSMutableArray *legendItems = [NSMutableArray array];
    for (NSInteger i = 0; i < 2; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = legendColors[i]; dot.layer.cornerRadius = 3;
        [dot.widthAnchor constraintEqualToConstant:8].active = YES; [dot.heightAnchor constraintEqualToConstant:8].active = YES;
        UILabel *l = GSLabel(legendNames[i], GSFont(9, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        l.numberOfLines = 1;
        UIStackView *item = GSStack(@[dot, l], UILayoutConstraintAxisHorizontal, 4);
        [legendItems addObject:item];
    }
    UIStackView *legend = GSStack(legendItems, UILayoutConstraintAxisHorizontal, 16);
    legend.distribution = UIStackViewDistributionFillEqually;
    UILabel *chartNote = GSLabel(@"柱高为当月总工时；颜色只分段正班与其他工时，补贴不在工时图中。", GSFont(9, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
    chartNote.numberOfLines = 0;
    [self.stack addArrangedSubview:[self cardWithTitle:@"十二个月工时结构" content:GSStack(@[chartWrap, legend, chartNote], UILayoutConstraintAxisVertical, 8)]];

    UIStackView *heat = [[UIStackView alloc] init];
    heat.axis = UILayoutConstraintAxisVertical; heat.spacing = 3;
    for (NSInteger m = 0; m < 12; m++) {
        NSMutableArray *cells = [NSMutableArray array];
        NSInteger dim = GSDaysInMonth(self.year, m + 1);
        for (NSInteger d = 1; d <= 31; d++) {
            UIView *c = [[UIView alloc] init];
            c.layer.cornerRadius = 1.5;
            c.backgroundColor = GSColorHex(@"#EEF2F7");
            if (d <= dim) {
                NSDictionary *r = [[GSStore shared] recordForDate:[NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)self.year, (long)(m + 1), (long)d]];
                double h = [[GSStore shared] dayHours:r];
                if (h >= 10) c.backgroundColor = GSThemeColor();
                else if (h >= 8) c.backgroundColor = [GSThemeColor() colorWithAlphaComponent:.68];
                else if (h >= 6) c.backgroundColor = [GSThemeColor() colorWithAlphaComponent:.42];
                else if (h > 0) c.backgroundColor = [GSThemeColor() colorWithAlphaComponent:.20];
            } else c.alpha = .3;
            [c.heightAnchor constraintEqualToConstant:6].active = YES;
            [cells addObject:c];
        }
        UIStackView *row = GSStack(cells, UILayoutConstraintAxisHorizontal, 2);
        row.distribution = UIStackViewDistributionFillEqually;
        [heat addArrangedSubview:row];
    }
    [self.stack addArrangedSubview:[self cardWithTitle:@"全年节奏" content:heat]];
    [self buildIncome:st];
}
- (void)tapBar:(UITapGestureRecognizer *)g { GSHaptic(); }
- (void)exportHTML {
    NSDictionary *st = [[GSStore shared] yearStats:self.year];
    NSArray *months = st[@"months"];
    double maxH = 1;
    NSInteger activeMonths = 0;
    for (NSDictionary *m in months) {
        maxH = MAX(maxH, [m[@"hours"] doubleValue]);
        if ([m[@"hours"] doubleValue] > 0) activeMonths++;
    }
    double avgMonthPay = activeMonths > 0 ? [st[@"pay"] doubleValue] / activeMonths : 0;
    NSString *accent = GSThemeHexValue() ?: @"#1859D9";
    NSString *(^esc)(NSString *) = ^NSString *(NSString *text) {
        if (![text isKindOfClass:[NSString class]]) return @"";
        text = [text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        text = [text stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        text = [text stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
        text = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
        return text;
    };
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>工时记录年度看板</title><style>"];
    [html appendString:@":root{--accent:"];
    [html appendString:accent];
    [html appendString:@";--ink:#14213d;--muted:#667085;--line:#e6ebf5;--soft:#f2f6ff}*{box-sizing:border-box}body{margin:0;background:#eef3fb;color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif}.wrap{max-width:920px;margin:0 auto;padding:20px}.hero{background:linear-gradient(135deg,var(--accent),#123b8f);color:white;border-radius:28px;padding:26px;box-shadow:0 18px 45px rgba(18,59,143,.22)}.eyebrow{margin:0 0 8px;font-size:12px;letter-spacing:.12em;opacity:.8}.hero h1{margin:0;font-size:34px}.hero .pay{font-size:38px;font-weight:800;margin-top:8px}.hero p{margin:8px 0 0;color:rgba(255,255,255,.82);font-size:13px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:16px}.stat{background:white;border:1px solid var(--line);border-radius:16px;padding:13px}.stat b{display:block;font-size:18px}.stat span{display:block;color:var(--muted);font-size:11px;margin-top:3px}.card{background:white;border:1px solid var(--line);border-radius:22px;padding:18px;margin-top:14px}.card h2{font-size:16px;margin:0 0 14px}.chart{display:flex;align-items:flex-end;gap:7px;height:160px;padding-top:10px}.col{flex:1;text-align:center;display:flex;flex-direction:column;justify-content:flex-end;height:100%}.bar{min-height:4px;display:flex;flex-direction:column-reverse;border-radius:6px;overflow:hidden;background:var(--soft);margin:0 auto;width:16px}.bar span{display:block;width:100%}.col small{color:var(--muted);font-size:9px;margin-top:5px}.legend{display:flex;gap:16px;color:var(--muted);font-size:11px;margin-top:8px}.dot{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:4px;vertical-align:1px}.scroll{overflow-x:auto}table{width:100%;border-collapse:collapse;font-size:12px;min-width:680px}th,td{padding:9px 7px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{color:var(--muted);font-weight:500;font-size:10px}tr:last-child td{border-bottom:0}.money{font-weight:700}.green{color:#067647}.red{color:#b42318}.foot{color:var(--muted);font-size:10px;text-align:center;padding:18px 0 32px}@media(max-width:640px){.wrap{padding:12px}.grid{grid-template-columns:repeat(2,1fr)}.hero{border-radius:22px;padding:20px}.hero h1{font-size:28px}.hero .pay{font-size:30px}}</style></head><body><div class=\"wrap\">"];
    [html appendFormat:@"<header class=\"hero\"><p class=\"eyebrow\">工时记录 · 年度看板</p><h1>%ld 年</h1><div class=\"pay\">%@</div><p>%@ 天出勤 · %@ 小时 · 平均时薪 %.0f 元</p></header>", (long)self.year, esc(GSMoney([st[@"pay"] doubleValue])), GSNum([st[@"days"] doubleValue]), GSNum([st[@"hours"] doubleValue]), [st[@"avg"] doubleValue]];
    [html appendString:@"<div class=\"grid\">"];
    [html appendFormat:@"<div class=\"stat\"><b>%@H</b><span>总工时</span></div><div class=\"stat\"><b>%@天</b><span>出勤</span></div><div class=\"stat\"><b>%@H</b><span>加班/周末/节假</span></div><div class=\"stat\"><b>%@</b><span>补贴</span></div><div class=\"stat\"><b>%@</b><span>扣款</span></div><div class=\"stat\"><b>%@</b><span>实发工资</span></div><div class=\"stat\"><b>%@H</b><span>日均工时</span></div><div class=\"stat\"><b>%@</b><span>月均工资</span></div>", GSNum([st[@"hours"] doubleValue]), GSNum([st[@"days"] doubleValue]), GSNum([st[@"ot"] doubleValue]), esc(GSMoney([st[@"bonus"] doubleValue])), esc(GSMoney([st[@"deduct"] doubleValue])), esc(GSMoney([st[@"pay"] doubleValue])), GSNum([st[@"days"] doubleValue] > 0 ? [st[@"hours"] doubleValue] / [st[@"days"] doubleValue] : 0), esc(GSMoney(avgMonthPay))];
    [html appendString:@"</div>"];
    [html appendString:@"<section class=\"card\"><h2>十二个月工时结构</h2><div class=\"chart\">"];
    for (NSInteger i = 0; i < 12; i++) {
        NSDictionary *m = months[i];
        double total = [m[@"hours"] doubleValue];
        double normal = [m[@"zb"] doubleValue];
        double other = MAX(0, total - normal);
        double full = total > 0 ? 4 + total / maxH * 108 : 4;
        double nh = total > 0 ? full * normal / total : 0;
        double oh = total > 0 ? full * other / total : 0;
        [html appendFormat:@"<div class=\"col\"><div class=\"bar\" style=\"height:%.0fpx\"><span style=\"height:%.0fpx;background:%@\"></span><span style=\"height:%.0fpx;background:#D92D20\"></span></div><small>%ld</small></div>", full, nh, accent, oh, (long)(i + 1)];
    }
    [html appendString:@"</div><div class=\"legend\"><span><i class=\"dot\" style=\"background:"];
    [html appendString:accent];
    [html appendString:@"\"></i>正班</span><span><i class=\"dot\" style=\"background:#D92D20\"></i>加班/周末/节假</span></div></section>"];
    [html appendString:@"<section class=\"card\"><h2>月度明细</h2><div class=\"scroll\"><table><thead><tr><th>月份</th><th>出勤</th><th>总工时</th><th>正班</th><th>加班</th><th>周末</th><th>节假</th><th>补贴</th><th>扣款</th><th>实发</th></tr></thead><tbody>"];
    for (NSInteger i = 0; i < 12; i++) {
        NSDictionary *m = months[i];
        [html appendFormat:@"<tr><td>%ld月</td><td>%@天</td><td>%@H</td><td>%@H</td><td>%@H</td><td>%@H</td><td>%@H</td><td class=\"green\">+%@</td><td class=\"red\">-%@</td><td class=\"money\">%@</td></tr>", (long)(i + 1), GSNum([m[@"days"] doubleValue]), GSNum([m[@"hours"] doubleValue]), GSNum([m[@"zb"] doubleValue]), GSNum([m[@"jb"] doubleValue]), GSNum([m[@"zm"] doubleValue]), GSNum([m[@"jj"] doubleValue]), esc(GSMoney([m[@"bonus"] doubleValue])), esc(GSMoney([m[@"deduct"] doubleValue])), esc(GSMoney([m[@"pay"] doubleValue]))];
    }
    [html appendString:@"</tbody></table></div></section>"];
    [html appendFormat:@"<div class=\"foot\">由工时记录生成 · %@</div></div></body></html>", GSKeyFromDate([NSDate date])];
    NSString *name = [NSString stringWithFormat:@"工时记录-%ld-看板.html", (long)self.year];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[html dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    [self presentViewController:a animated:YES completion:nil];
}
@end
@interface GSStackedBar : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *values;
@property (nonatomic, copy) NSArray<UIColor *> *colors;
@end
@implementation GSStackedBar
- (void)layoutSubviews {
    [super layoutSubviews];
    double total = 0; for (NSNumber *n in self.values) total += n.doubleValue;
    if (total <= 0) total = 1;
    CGFloat x = 0;
    for (NSInteger i = 0; i < (NSInteger)self.values.count; i++) {
        CGFloat w = self.bounds.size.width * (self.values[i].doubleValue / total);
        UIView *v = self.subviews.count > i ? self.subviews[i] : nil;
        if (!v) { v = [[UIView alloc] init]; [self addSubview:v]; }
        v.frame = CGRectMake(x, 0, w, self.bounds.size.height);
        v.backgroundColor = self.colors[i];
        x += w;
    }
}
@end
@implementation GSScheduleViewController (Build)
- (void)buildIncome:(NSDictionary *)st {
    double work = [st[@"workPay"] doubleValue], bonus = [st[@"bonus"] doubleValue], deduct = [st[@"deduct"] doubleValue];
    double allPay = [st[@"pay"] doubleValue], allDays = [st[@"days"] doubleValue];
    double avgDayPay = allDays > 0 ? allPay / allDays : 0;
    GSStackedBar *bar = [[GSStackedBar alloc] init];
    bar.values = @[@(MAX(0, work)), @(MAX(0, bonus))];
    bar.colors = @[GSThemeColor(), GSColorHex(@"#067647")];
    bar.layer.cornerRadius = 6; bar.clipsToBounds = YES;
    [bar.heightAnchor constraintEqualToConstant:12].active = YES;
    UILabel *l1 = GSLabel([NSString stringWithFormat:@"工时工资  %@", GSMoney(work)], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
    UILabel *l2 = GSLabel([NSString stringWithFormat:@"日均工资  %@", GSMoney(avgDayPay)], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
    UILabel *l3 = GSLabel([NSString stringWithFormat:@"补贴  %@", GSMoney(bonus)], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
    UILabel *l4 = GSLabel([NSString stringWithFormat:@"扣款  -%@", GSMoney(deduct)], GSFont(12, UIFontWeightRegular), GSColorHex(@"#667085"));
    UIStackView *r1 = GSStack(@[l1, l2], UILayoutConstraintAxisHorizontal, 12); r1.distribution = UIStackViewDistributionFillEqually;
    UIStackView *r2 = GSStack(@[l3, l4], UILayoutConstraintAxisHorizontal, 12); r2.distribution = UIStackViewDistributionFillEqually;
    UIStackView *legend = GSStack(@[r1, r2], UILayoutConstraintAxisVertical, 6);
    UILabel *netPay = GSLabel([NSString stringWithFormat:@"实发工资  %@", GSMoney(allPay)], GSFont(13, UIFontWeightBold), GSThemeColor());
    GSCardView *card = [self cardWithTitle:@"收入构成" content:GSStack(@[bar, legend, netPay], UILayoutConstraintAxisVertical, 10)];
    [self.stack addArrangedSubview:card];

    NSMutableArray *rows = [NSMutableArray array];
    UILabel *head = GSLabel(@"月度明细", GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
    [rows addObject:head];
    NSArray *months = st[@"months"];
    for (NSInteger i = 0; i < 12; i++) {
        NSDictionary *m = months[i];
        UILabel *name = GSLabel([NSString stringWithFormat:@"%ld月", (long)(i + 1)], GSFont(13, UIFontWeightSemibold), GSColorHex(@"#101828"));
        UILabel *p = GSLabel(GSMoney([m[@"pay"] doubleValue]), GSFont(13, UIFontWeightBold), GSColorHex(@"#101828"));
        p.textAlignment = NSTextAlignmentRight;
        UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
        UIStackView *top = GSStack(@[name, sp, p], UILayoutConstraintAxisHorizontal, 8);
        UILabel *detail = GSLabel([NSString stringWithFormat:@"%@天 · %@H · 正班 %@H / 加班 %@H / 周末 %@H / 节假 %@H", GSNum([m[@"days"] doubleValue]), GSNum([m[@"hours"] doubleValue]), GSNum([m[@"zb"] doubleValue]), GSNum([m[@"jb"] doubleValue]), GSNum([m[@"zm"] doubleValue]), GSNum([m[@"jj"] doubleValue])], GSFont(9, UIFontWeightRegular), GSColorHex(@"#667085"));
        detail.numberOfLines = 0;
        UILabel *extra = GSLabel([NSString stringWithFormat:@"补贴 +%@  ·  扣款 -%@  ·  净额 %@", GSMoney([m[@"bonus"] doubleValue]), GSMoney([m[@"deduct"] doubleValue]), GSMoney([m[@"bonus"] doubleValue] - [m[@"deduct"] doubleValue])], GSFont(9, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
        extra.numberOfLines = 0;
        UIStackView *row = GSStack(@[top, detail, extra], UILayoutConstraintAxisVertical, 2);
        [rows addObject:row];
        if (i < 11) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = GSColorHex(@"#F2F4F7");
            [line.heightAnchor constraintEqualToConstant:1].active = YES;
            [rows addObject:line];
        }
    }
    UILabel *allTitle = GSLabel(@"全年合计", GSFont(12, UIFontWeightBold), GSThemeColor());
    UILabel *allDetail = GSLabel([NSString stringWithFormat:@"%@天 · %@H · 补贴 +%@ · 扣款 -%@", GSNum([st[@"days"] doubleValue]), GSNum([st[@"hours"] doubleValue]), GSMoney([st[@"bonus"] doubleValue]), GSMoney([st[@"deduct"] doubleValue])], GSFont(9, UIFontWeightRegular), GSColorHex(@"#667085"));
    allDetail.numberOfLines = 0;
    UILabel *allPayLabel = GSLabel(GSMoney([st[@"pay"] doubleValue]), GSFont(15, UIFontWeightBold), GSThemeColor());
    allPayLabel.textAlignment = NSTextAlignmentRight;
    UIView *allSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    [rows addObject:GSStack(@[allTitle, allSp, allPayLabel], UILayoutConstraintAxisHorizontal, 8)];
    [rows addObject:allDetail];
    GSCardView *list = [[GSCardView alloc] init];
    UIStackView *lv = GSStack(rows, UILayoutConstraintAxisVertical, 7);
    lv.translatesAutoresizingMaskIntoConstraints = NO; [list addSubview:lv];
    [NSLayoutConstraint activateConstraints:@[
        [lv.topAnchor constraintEqualToAnchor:list.topAnchor constant:16], [lv.leadingAnchor constraintEqualToAnchor:list.leadingAnchor constant:16],
        [lv.trailingAnchor constraintEqualToAnchor:list.trailingAnchor constant:-16], [lv.bottomAnchor constraintEqualToAnchor:list.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:list];
}
- (void)buildSchedule {
    NSMutableArray *navViews = [NSMutableArray array];
    UIButton *prev = GSIconButton(@"chevron.left", GSColorHex(@"#101828"), 15);
    UIButton *next = GSIconButton(@"chevron.right", GSColorHex(@"#101828"), 15);
    prev.backgroundColor = UIColor.whiteColor; prev.layer.cornerRadius = 12;
    next.backgroundColor = UIColor.whiteColor; next.layer.cornerRadius = 12;
    [prev.widthAnchor constraintEqualToConstant:34].active = YES; [prev.heightAnchor constraintEqualToConstant:34].active = YES;
    [next.widthAnchor constraintEqualToConstant:34].active = YES; [next.heightAnchor constraintEqualToConstant:34].active = YES;
    [prev addTarget:self action:@selector(prevScheduleMonth) forControlEvents:UIControlEventTouchUpInside];
    [next addTarget:self action:@selector(nextScheduleMonth) forControlEvents:UIControlEventTouchUpInside];
    UILabel *month = GSLabel([NSString stringWithFormat:@"%ld年 %ld月", (long)self.year, (long)self.month], GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
    UIView *sp1 = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIView *sp2 = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *nav = GSStack(@[prev, sp1, month, sp2, next], UILayoutConstraintAxisHorizontal, 8);
    nav.alignment = UIStackViewAlignmentCenter;
    [navViews addObject:nav];

    GSCalendarView *cal = [[GSCalendarView alloc] init];
    cal.year = self.year; cal.month = self.month; cal.selectedDate = self.selectedDate;
    __weak typeof(self) weakSelf = self;
    cal.onSelect = ^(NSString *date) { [weakSelf assignPlan:date]; };
    self.scheduleCalendar = cal;
    cal.translatesAutoresizingMaskIntoConstraints = NO;
    [cal.heightAnchor constraintEqualToConstant:404].active = YES;
    [cal reload];
    [navViews addObject:cal];

    NSMutableArray *chips = [NSMutableArray array];
    NSMutableArray *classChips = [NSMutableArray array];
    NSArray *classes = [[GSStore shared] classes];
    for (NSDictionary *c in classes) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:c[@"name"] forState:UIControlStateNormal]; b.titleLabel.font = GSFont(12, UIFontWeightSemibold);
        b.tag = [classes indexOfObject:c];
        BOOL on = [self.palette isEqual:c[@"id"]];
        b.backgroundColor = on ? GSThemeSoftColor() : GSColorHex(@"#F2F5FA");
        b.layer.cornerRadius = 12; b.layer.borderWidth = 1.5;
        b.layer.borderColor = (on ? GSThemeColor() : UIColor.clearColor).CGColor;
        [b setTitleColor:(on ? GSThemeColor() : GSColorHex(@"#667085")) forState:UIControlStateNormal];
        [b.heightAnchor constraintEqualToConstant:36].active = YES;
        [b addTarget:self action:@selector(paletteTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chips addObject:b]; [classChips addObject:b];
    }
    self.classChips = classChips;
    UIButton *clear = [UIButton buttonWithType:UIButtonTypeCustom];
    [clear setTitle:@"清除" forState:UIControlStateNormal]; clear.titleLabel.font = GSFont(12, UIFontWeightSemibold);
    clear.backgroundColor = GSColorHex(@"#F2F5FA"); clear.layer.cornerRadius = 10;
    [clear setTitleColor:GSColorHex(@"#667085") forState:UIControlStateNormal];
    [clear.heightAnchor constraintEqualToConstant:36].active = YES;
    [clear addTarget:self action:@selector(clearPlan) forControlEvents:UIControlEventTouchUpInside];
    [chips addObject:clear];
    UIStackView *palette = GSStack(chips, UILayoutConstraintAxisHorizontal, 6);
    palette.distribution = UIStackViewDistributionFillEqually;
    GSCardView *pc = [[GSCardView alloc] init];
    UILabel *pt = GSLabel(@"班次 · 选一个再点日期", GSFont(11, UIFontWeightMedium), GSColorHex(@"#5D6B82"));
    self.scheduleHint = GSLabel(@"", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UIStackView *pv = GSStack(@[pt, self.scheduleHint, palette], UILayoutConstraintAxisVertical, 8);
    pv.translatesAutoresizingMaskIntoConstraints = NO; [pc addSubview:pv];
    [NSLayoutConstraint activateConstraints:@[
        [pv.topAnchor constraintEqualToAnchor:pc.topAnchor constant:14], [pv.leadingAnchor constraintEqualToAnchor:pc.leadingAnchor constant:14],
        [pv.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor constant:-14], [pv.bottomAnchor constraintEqualToAnchor:pc.bottomAnchor constant:-14]
    ]];
    [navViews addObject:pc];
    [self updateScheduleHint];
    [navViews addObject:GSLabel(@"排班只做标记，不会自动生成工时；记录页仍按实际工时算工资。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"))];
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *v = GSStack(navViews, UILayoutConstraintAxisVertical, 14);
    v.translatesAutoresizingMaskIntoConstraints = NO; [card addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:16], [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16], [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:card];
    GSAnimateStack(self.stack);
}
- (void)prevScheduleMonth {
    NSDateComponents *c = GSMonthAdd(self.year, self.month, -1);
    self.year = c.year; self.month = c.month;
    self.selectedDate = [NSString stringWithFormat:@"%04ld-%02ld-01", (long)self.year, (long)self.month];
    [self reload];
}
- (void)nextScheduleMonth {
    NSDateComponents *c = GSMonthAdd(self.year, self.month, 1);
    self.year = c.year; self.month = c.month;
    self.selectedDate = [NSString stringWithFormat:@"%04ld-%02ld-01", (long)self.year, (long)self.month];
    [self reload];
}
- (void)updatePaletteChips {
    NSArray *classes = [[GSStore shared] classes];
    for (UIButton *b in self.classChips) {
        if (b.tag < 0 || b.tag >= (NSInteger)classes.count) continue;
        NSDictionary *c = classes[b.tag];
        BOOL on = [self.palette isEqual:c[@"id"]];
        b.backgroundColor = on ? GSThemeSoftColor() : GSColorHex(@"#F2F5FA");
        b.layer.borderWidth = 1.5;
        b.layer.borderColor = (on ? GSThemeColor() : UIColor.clearColor).CGColor;
        [b setTitleColor:(on ? GSThemeColor() : GSColorHex(@"#667085")) forState:UIControlStateNormal];
    }
}
- (void)updateScheduleHint {
    NSDictionary *c = [[GSStore shared] classWithId:self.palette];
    NSString *name = c[@"name"] ?: @"未选班次";
    if (self.scheduleHint) self.scheduleHint.text = [NSString stringWithFormat:@"当前：%@ · 点日期排班", name];
}
- (void)paletteTapped:(UIButton *)b {
    NSArray *classes = [[GSStore shared] classes];
    if (b.tag < 0 || b.tag >= (NSInteger)classes.count) return;
    self.palette = classes[b.tag][@"id"];
    [self updatePaletteChips];
    [self updateScheduleHint];
}
- (void)assignPlan:(NSString *)date {
    if (!self.palette.length) return;
    [[GSStore shared] setPlan:self.palette forDate:date];
    self.selectedDate = date;
    self.scheduleCalendar.selectedDate = date;
    [self.scheduleCalendar reload];
    [self updateScheduleHint];
    GSHaptic();
}
- (void)clearPlan {
    [[GSStore shared] setPlan:@"" forDate:self.selectedDate];
    [self.scheduleCalendar reload];
    [self updateScheduleHint];
    GSToast(@"已清除");
}
@end
