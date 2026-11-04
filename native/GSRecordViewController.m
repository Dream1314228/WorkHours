#import "GSRecordViewController.h"
#import "GSComponents.h"
#import "GSCalendarView.h"
#import "GSStore.h"
#import "GSEditorViewController.h"
#import "GSBatchViewController.h"

@interface GSRecordViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *statusBg;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *yearLabel, *relLabel, *monthLabel;
@property (nonatomic, strong) UILabel *daysValue, *hoursValue, *payValue;
@property (nonatomic, strong) GSCalendarView *calendar;
@property (nonatomic, strong) GSCardView *dayCard;
@property (nonatomic, strong) GSCardView *timelineCard;
@property (nonatomic, strong) UIStackView *timelineStack;
@property (nonatomic, strong) UIView *toolRow;
@property (nonatomic, strong) UIButton *batchBtn, *deleteBtn, *fab, *todayBtn;
@property (nonatomic, strong) UILabel *fabLabel;
@property (nonatomic, strong) UIImageView *fabIcon;
@property (nonatomic, copy) NSString *selectedDate;
@property (nonatomic, assign) NSInteger year, month;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight, *statusHeight, *yearTop, *monthTop;
@property (nonatomic, assign) BOOL statusDark;
@end
@implementation GSRecordViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
    NSDate *d = [NSDate date];
    if ([[GSStore shared].settings[@"nightMode"] boolValue]) {
        NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        if ([cal component:NSCalendarUnitHour fromDate:d] < 6) d = [d dateByAddingTimeInterval:-86400];
    }
    self.selectedDate = GSKeyFromDate(d);
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    self.year = [cal component:NSCalendarUnitYear fromDate:d];
    self.month = [cal component:NSCalendarUnitMonth fromDate:d];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.backgroundColor = UIColor.clearColor;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.showsVerticalScrollIndicator = NO;
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0, 110, 0);
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

    self.yearLabel = GSLabel(@"", GSFont(26, UIFontWeightBold), UIColor.whiteColor);
    self.relLabel = GSLabel(@"", GSFont(12, UIFontWeightMedium), [UIColor colorWithWhite:1 alpha:.92]);
    self.monthLabel = GSLabel(@"", GSFont(18, UIFontWeightBold), UIColor.whiteColor);
    self.yearLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.relLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.monthLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:self.yearLabel]; [self.header addSubview:self.relLabel]; [self.header addSubview:self.monthLabel];

    UIButton *prev = GSIconButton(@"chevron.left", UIColor.whiteColor, 18);
    UIButton *next = GSIconButton(@"chevron.right", UIColor.whiteColor, 18);
    prev.translatesAutoresizingMaskIntoConstraints = NO; next.translatesAutoresizingMaskIntoConstraints = NO;
    [prev addTarget:self action:@selector(prevMonth) forControlEvents:UIControlEventTouchUpInside];
    [next addTarget:self action:@selector(nextMonth) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:prev]; [self.header addSubview:next];

    UIView *summary = [[UIView alloc] init];
    summary.backgroundColor = [UIColor colorWithWhite:0 alpha:.09];
    summary.layer.cornerRadius = 20; summary.layer.borderWidth = 1;
    summary.layer.borderColor = [UIColor colorWithWhite:1 alpha:.18].CGColor;
    summary.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:summary];
    NSMutableArray *cols = [NSMutableArray array];
    NSArray *titles = @[@"出勤", @"工时", @"工资"];
    NSMutableArray *values = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        UILabel *v = GSLabel(@"0", GSFont(19, UIFontWeightBold), UIColor.whiteColor); v.textAlignment = NSTextAlignmentCenter;
        UILabel *t = GSLabel(titles[i], GSFont(11, UIFontWeightRegular), [UIColor colorWithWhite:1 alpha:.92]); t.textAlignment = NSTextAlignmentCenter;
        [cols addObject:GSStack(@[v, t], UILayoutConstraintAxisVertical, 2)]; [values addObject:v];
    }
    self.daysValue = values[0]; self.hoursValue = values[1]; self.payValue = values[2];
    UIStackView *sumStack = GSStack(cols, UILayoutConstraintAxisHorizontal, 0);
    sumStack.distribution = UIStackViewDistributionFillEqually;
    sumStack.translatesAutoresizingMaskIntoConstraints = NO;
    [summary addSubview:sumStack];

    self.calendar = [[GSCalendarView alloc] init];
    self.calendar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.calendar];
    __weak typeof(self) weakSelf = self;
    self.calendar.onSelect = ^(NSString *date) { weakSelf.selectedDate = date; [weakSelf reload]; };

    self.dayCard = [[GSCardView alloc] init];
    self.dayCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.dayCard];
    [self.dayCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openEditor)]];

    self.timelineCard = [[GSCardView alloc] init];
    self.timelineCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.timelineCard];
    self.timelineStack = [[UIStackView alloc] init];
    self.timelineStack.axis = UILayoutConstraintAxisVertical; self.timelineStack.spacing = 8;
    self.timelineStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.timelineCard addSubview:self.timelineStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.timelineStack.topAnchor constraintEqualToAnchor:self.timelineCard.topAnchor constant:14],
        [self.timelineStack.leadingAnchor constraintEqualToAnchor:self.timelineCard.leadingAnchor constant:16],
        [self.timelineStack.trailingAnchor constraintEqualToAnchor:self.timelineCard.trailingAnchor constant:-16],
        [self.timelineStack.bottomAnchor constraintEqualToAnchor:self.timelineCard.bottomAnchor constant:-14]
    ]];

    self.toolRow = [[UIView alloc] init];
    self.toolRow.backgroundColor = UIColor.whiteColor;
    self.toolRow.layer.cornerRadius = 16;
    self.toolRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.toolRow];
    self.batchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.batchBtn setTitle:@"批量设置工时" forState:UIControlStateNormal];
    [self.batchBtn setImage:GSIcon(@"calendar.badge.plus", 15) forState:UIControlStateNormal];
    [self.batchBtn setTitleColor:GSThemeColor() forState:UIControlStateNormal];
    self.batchBtn.tintColor = GSThemeColor();
    self.batchBtn.titleLabel.font = GSFont(12, UIFontWeightSemibold);
    self.batchBtn.backgroundColor = GSThemeSoftColor();
    self.batchBtn.layer.cornerRadius = 10;
    [self.batchBtn addTarget:self action:@selector(openBatch) forControlEvents:UIControlEventTouchUpInside];
    self.deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.deleteBtn setTitle:@"删除当前工时" forState:UIControlStateNormal];
    [self.deleteBtn setImage:GSIcon(@"trash", 14) forState:UIControlStateNormal];
    [self.deleteBtn setTitleColor:GSColorHex(@"#B42318") forState:UIControlStateNormal];
    self.deleteBtn.tintColor = GSColorHex(@"#B42318");
    self.deleteBtn.titleLabel.font = GSFont(12, UIFontWeightSemibold);
    self.deleteBtn.backgroundColor = GSColorHex(@"#FEF3F2");
    self.deleteBtn.layer.cornerRadius = 10;
    [self.deleteBtn addTarget:self action:@selector(deleteCurrentRecord) forControlEvents:UIControlEventTouchUpInside];
    UIButton *batch = self.batchBtn, *del = self.deleteBtn;
    batch.translatesAutoresizingMaskIntoConstraints = NO; del.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolRow addSubview:batch]; [self.toolRow addSubview:del];
    [NSLayoutConstraint activateConstraints:@[
        [batch.leadingAnchor constraintEqualToAnchor:self.toolRow.leadingAnchor constant:10],
        [batch.centerYAnchor constraintEqualToAnchor:self.toolRow.centerYAnchor],
        [batch.heightAnchor constraintEqualToConstant:34],
        [del.trailingAnchor constraintEqualToAnchor:self.toolRow.trailingAnchor constant:-10],
        [del.centerYAnchor constraintEqualToAnchor:self.toolRow.centerYAnchor],
        [del.heightAnchor constraintEqualToConstant:34],
        [batch.trailingAnchor constraintEqualToAnchor:del.leadingAnchor constant:-8],
        [batch.widthAnchor constraintEqualToAnchor:del.widthAnchor]
    ]];

    self.fab = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fab.translatesAutoresizingMaskIntoConstraints = NO;
    self.fab.layer.cornerRadius = 23;
    self.fab.layer.shadowColor = GSThemeColor().CGColor;
    self.fab.layer.shadowOpacity = .30; self.fab.layer.shadowRadius = 12; self.fab.layer.shadowOffset = CGSizeMake(0, 6);
    self.fab.tintColor = UIColor.whiteColor;
    self.fab.contentEdgeInsets = UIEdgeInsetsZero;
    self.fab.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.fab.accessibilityLabel = @"记一笔";
    CAGradientLayer *gl = [CAGradientLayer layer];
    gl.colors = @[(id)GSThemeColor().CGColor, (id)GSThemeDarkColor().CGColor];
    gl.startPoint = CGPointMake(0, 0); gl.endPoint = CGPointMake(1, 1);
    gl.frame = CGRectMake(0, 0, 102, 46); gl.cornerRadius = 23;
    [self.fab.layer insertSublayer:gl atIndex:0];
    [self.fab addTarget:self action:@selector(primaryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.fab];
    self.fabLabel = GSLabel(@"记一笔", GSFont(14, UIFontWeightSemibold), UIColor.whiteColor);
    self.fabLabel.textAlignment = NSTextAlignmentCenter;
    self.fabLabel.userInteractionEnabled = NO;
    self.fabIcon = [[UIImageView alloc] initWithImage:GSIcon(@"plus", 14)];
    self.fabIcon.tintColor = UIColor.whiteColor;
    self.fabIcon.contentMode = UIViewContentModeCenter;
    self.fabIcon.userInteractionEnabled = NO;
    self.fabLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fabIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.fab addSubview:self.fabLabel];
    [self.fab addSubview:self.fabIcon];
    [NSLayoutConstraint activateConstraints:@[
        [self.fabLabel.centerXAnchor constraintEqualToAnchor:self.fab.centerXAnchor],
        [self.fabLabel.centerYAnchor constraintEqualToAnchor:self.fab.centerYAnchor],
        [self.fabIcon.leadingAnchor constraintEqualToAnchor:self.fab.leadingAnchor constant:14],
        [self.fabIcon.centerYAnchor constraintEqualToAnchor:self.fab.centerYAnchor],
        [self.fabIcon.widthAnchor constraintEqualToConstant:14],
        [self.fabIcon.heightAnchor constraintEqualToConstant:14]
    ]];

    self.todayBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.todayBtn.translatesAutoresizingMaskIntoConstraints = NO;
    self.todayBtn.backgroundColor = UIColor.whiteColor;
    self.todayBtn.layer.cornerRadius = 22;
    self.todayBtn.layer.shadowColor = [UIColor colorWithWhite:0 alpha:.18].CGColor;
    self.todayBtn.layer.shadowOpacity = .22; self.todayBtn.layer.shadowRadius = 8; self.todayBtn.layer.shadowOffset = CGSizeMake(0, 4);
    [self.todayBtn setImage:GSIcon(@"arrow.uturn.backward", 13) forState:UIControlStateNormal];
    [self.todayBtn setTitle:@"今天" forState:UIControlStateNormal];
    [self.todayBtn setTitleColor:GSThemeColor() forState:UIControlStateNormal];
    self.todayBtn.titleLabel.font = GSFont(11, UIFontWeightSemibold);
    self.todayBtn.tintColor = GSThemeColor();
    self.todayBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 2);
    self.todayBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 2, 0, -2);
    self.todayBtn.accessibilityLabel = @"回到今天";
    [self.todayBtn addTarget:self action:@selector(goToday) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.todayBtn];

    self.statusBg.hidden = YES;
    self.scroll.delegate = self;
    self.statusHeight = [self.statusBg.heightAnchor constraintEqualToConstant:64];
    self.headerHeight = [self.header.heightAnchor constraintEqualToConstant:230];
    self.yearTop = [self.yearLabel.topAnchor constraintEqualToAnchor:self.header.topAnchor constant:72];
    self.monthTop = [self.monthLabel.topAnchor constraintEqualToAnchor:self.header.topAnchor constant:14];
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
        [self.yearLabel.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        self.yearTop,
        [self.relLabel.leadingAnchor constraintEqualToAnchor:self.yearLabel.trailingAnchor constant:6],
        [self.relLabel.lastBaselineAnchor constraintEqualToAnchor:self.yearLabel.lastBaselineAnchor],
        self.monthTop,
        [next.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [next.centerYAnchor constraintEqualToAnchor:self.monthLabel.centerYAnchor],
        [self.monthLabel.trailingAnchor constraintEqualToAnchor:next.leadingAnchor constant:-8],
        [prev.trailingAnchor constraintEqualToAnchor:self.monthLabel.leadingAnchor constant:-8],
        [prev.centerYAnchor constraintEqualToAnchor:self.monthLabel.centerYAnchor],
        [prev.widthAnchor constraintEqualToConstant:30], [prev.heightAnchor constraintEqualToConstant:30],
        [next.widthAnchor constraintEqualToConstant:30], [next.heightAnchor constraintEqualToConstant:30],
        [summary.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [summary.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [summary.heightAnchor constraintEqualToConstant:72],
        [summary.bottomAnchor constraintEqualToAnchor:self.header.bottomAnchor constant:-20],
        [sumStack.leadingAnchor constraintEqualToAnchor:summary.leadingAnchor constant:6],
        [sumStack.trailingAnchor constraintEqualToAnchor:summary.trailingAnchor constant:-6],
        [sumStack.centerYAnchor constraintEqualToAnchor:summary.centerYAnchor],
        [self.calendar.topAnchor constraintEqualToAnchor:self.header.bottomAnchor constant:14],
        [self.calendar.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:18],
        [self.calendar.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [self.calendar.heightAnchor constraintEqualToConstant:404],
        [self.dayCard.topAnchor constraintEqualToAnchor:self.calendar.bottomAnchor constant:14],
        [self.dayCard.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:18],
        [self.dayCard.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [self.timelineCard.topAnchor constraintEqualToAnchor:self.dayCard.bottomAnchor constant:12],
        [self.timelineCard.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:18],
        [self.timelineCard.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [self.toolRow.topAnchor constraintEqualToAnchor:self.timelineCard.bottomAnchor constant:12],
        [self.toolRow.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:18],
        [self.toolRow.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [self.toolRow.heightAnchor constraintEqualToConstant:52],
        [self.toolRow.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-120],
        [self.fab.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.fab.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-86],
        [self.fab.widthAnchor constraintEqualToConstant:102], [self.fab.heightAnchor constraintEqualToConstant:46],
        [self.todayBtn.trailingAnchor constraintEqualToAnchor:self.fab.leadingAnchor constant:-8],
        [self.todayBtn.centerYAnchor constraintEqualToAnchor:self.fab.centerYAnchor],
        [self.todayBtn.widthAnchor constraintEqualToConstant:58], [self.todayBtn.heightAnchor constraintEqualToConstant:44]
    ]];
    [self.view bringSubviewToFront:self.statusBg];
    [self.view bringSubviewToFront:self.fab];
    [self.view bringSubviewToFront:self.todayBtn];
    [self reload];
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    CGFloat top = self.view.safeAreaInsets.top;
    self.statusHeight.constant = top;
    self.headerHeight.constant = top + 170;
    self.yearTop.constant = top + 12;
    self.monthTop.constant = top + 12;
    self.header.startY = top / MAX(1, self.headerHeight.constant);
    [self.header layoutIfNeeded];
    [self updateStatusStyle];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
    [self updateStatusStyle];
}
- (UIStatusBarStyle)preferredStatusBarStyle { return self.statusDark ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent; }
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { [self updateStatusStyle]; }
- (void)updateStatusStyle {
    CGFloat threshold = MAX(0, self.headerHeight.constant - self.view.safeAreaInsets.top);
    BOOL dark = self.scroll.contentOffset.y > threshold;
    if (dark != _statusDark) { _statusDark = dark; [self setNeedsStatusBarAppearanceUpdate]; [self.parentViewController setNeedsStatusBarAppearanceUpdate]; }
}
- (void)reload {
    NSDictionary *st = [[GSStore shared] monthStats:self.year month:self.month usePeriod:NO];
    self.yearLabel.text = [NSString stringWithFormat:@"%ld年", (long)self.year];
    self.relLabel.text = GSRelativeDay(self.selectedDate);
    self.monthLabel.text = [NSString stringWithFormat:@"%ld月", (long)self.month];
    self.daysValue.text = GSNum([st[@"days"] doubleValue]);
    self.hoursValue.text = GSNum([st[@"hours"] doubleValue]);
    self.payValue.text = GSMoney([st[@"pay"] doubleValue]);
    self.calendar.year = self.year; self.calendar.month = self.month; self.calendar.selectedDate = self.selectedDate;
    [self.calendar reload];
    BOOL hasRecord = [[GSStore shared] recordForDate:self.selectedDate] != nil;
    BOOL isToday = [self.selectedDate isEqual:GSTodayKey()];
    self.deleteBtn.enabled = hasRecord;
    self.deleteBtn.alpha = hasRecord ? 1 : .38;
    if (!hasRecord) {
        self.fab.hidden = NO;
        self.fabLabel.text = @"记一笔";
        self.fabIcon.image = GSIcon(@"plus", 14);
        self.fab.accessibilityLabel = @"记一笔";
        self.todayBtn.hidden = isToday;
    } else if (!isToday) {
        self.fab.hidden = NO;
        self.fabLabel.text = @"回今天";
        self.fabIcon.image = GSIcon(@"arrow.uturn.backward", 14);
        self.fab.accessibilityLabel = @"回到今天";
        self.todayBtn.hidden = YES;
    } else {
        self.fab.hidden = YES;
        self.todayBtn.hidden = YES;
    }
    [UIView transitionWithView:self.dayCard duration:0.22 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [self rebuildDayCard];
    } completion:nil];
    [self rebuildTimeline];
}
- (void)rebuildTimeline {
    for (UIView *v in self.timelineStack.arrangedSubviews) {
        [self.timelineStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    UILabel *title = GSLabel(@"工作时间轴", GSFont(13, UIFontWeightSemibold), GSColorHex(@"#344054"));
    UILabel *sub = GSLabel(@"按班次名和总工时估算，只作时间参考", GSFont(9, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
    UIStackView *head = GSStack(@[title, sub], UILayoutConstraintAxisVertical, 2);
    [self.timelineStack addArrangedSubview:head];
    NSDictionary *rec = [[GSStore shared] recordForDate:self.selectedDate];
    if (!rec) {
        UILabel *empty = GSLabel(@"当天还没有记录", GSFont(11, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
        [self.timelineStack addArrangedSubview:empty];
        return;
    }
    NSDictionary *work = rec[@"work"] ?: @{};
    double normal = [work[@"zb"] doubleValue] + [work[@"zm"] doubleValue] + [work[@"jj"] doubleValue];
    double overtime = [work[@"jb"] doubleValue];
    double leave = [rec[@"leave"][@"hour"] doubleValue];
    double total = normal + overtime + leave;
    NSDictionary *cls = [[GSStore shared] classWithId:rec[@"classId"]];
    NSString *name = cls[@"name"] ?: @"";
    double start = 8;
    if ([name containsString:@"早"]) start = 6;
    else if ([name containsString:@"中"]) start = 14;
    else if ([name containsString:@"晚"] || [name containsString:@"夜"]) start = 22;
    BOOL nextDay = start + total >= 24;
    double end = fmod(start + total, 24);
    NSString *range = total > 0 ? [NSString stringWithFormat:@"上班 %02.0f:00   ·   %@ %02.0f:00", start, nextDay ? @"次日下班" : @"下班", end] : @"当天没有工时";
    UILabel *rangeLabel = GSLabel(range, GSFont(15, UIFontWeightBold), GSThemeColor());
    [self.timelineStack addArrangedSubview:rangeLabel];
    UILabel *durationLabel = GSLabel(total > 0 ? [NSString stringWithFormat:@"共 %@H  ·  正常 %@H  ·  加班 %@H  ·  休假 %@H", GSNum(total), GSNum(normal), GSNum(overtime), GSNum(leave)] : @"记录里没有可展示的工时", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    [self.timelineStack addArrangedSubview:durationLabel];

    UIView *track = [[UIView alloc] init];
    track.backgroundColor = GSColorHex(@"#EEF2F7"); track.layer.cornerRadius = 8; track.clipsToBounds = YES;
    track.translatesAutoresizingMaskIntoConstraints = NO;
    [track.heightAnchor constraintEqualToConstant:16].active = YES;
    [self.timelineStack addArrangedSubview:track];
    UIStackView *segments = [[UIStackView alloc] init];
    segments.axis = UILayoutConstraintAxisHorizontal; segments.spacing = 0;
    segments.translatesAutoresizingMaskIntoConstraints = NO;
    [track addSubview:segments];
    [NSLayoutConstraint activateConstraints:@[
        [segments.leadingAnchor constraintEqualToAnchor:track.leadingAnchor], [segments.trailingAnchor constraintEqualToAnchor:track.trailingAnchor],
        [segments.topAnchor constraintEqualToAnchor:track.topAnchor], [segments.bottomAnchor constraintEqualToAnchor:track.bottomAnchor]
    ]];
    double visible = MIN(total, MAX(0, 24 - start));
    double leadRatio = start / 24.0;
    UIView *lead = [[UIView alloc] init]; lead.backgroundColor = UIColor.clearColor;
    [segments addArrangedSubview:lead];
    [lead.widthAnchor constraintEqualToAnchor:track.widthAnchor multiplier:leadRatio].active = YES;
    NSArray *vals = @[@(normal), @(overtime), @(leave)];
    NSArray *colors = @[GSThemeColor(), GSColorHex(@"#D92D20"), GSColorHex(@"#12B76A")];
    for (NSInteger i = 0; i < 3; i++) {
        double v = [vals[i] doubleValue];
        if (v <= 0 || total <= 0) continue;
        UIView *seg = [[UIView alloc] init];
        seg.backgroundColor = colors[i];
        [segments addArrangedSubview:seg];
        double segRatio = v / total * visible / 24.0;
        [seg.widthAnchor constraintEqualToAnchor:track.widthAnchor multiplier:MAX(0, segRatio)].active = YES;
    }
    UIView *tail = [[UIView alloc] init]; tail.backgroundColor = UIColor.clearColor;
    [segments addArrangedSubview:tail];
    double tailRatio = MAX(0, 1 - leadRatio - visible / 24.0);
    [tail.widthAnchor constraintEqualToAnchor:track.widthAnchor multiplier:tailRatio].active = YES;
    NSMutableArray *ticks = [NSMutableArray array];
    for (NSString *t in @[@"0", @"6", @"12", @"18", @"24"]) {
        UILabel *l = GSLabel(t, GSFont(8, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
        l.textAlignment = t.integerValue == 0 ? NSTextAlignmentLeft : (t.integerValue == 24 ? NSTextAlignmentRight : NSTextAlignmentCenter);
        [ticks addObject:l];
    }
    UIStackView *tickRow = GSStack(ticks, UILayoutConstraintAxisHorizontal, 0);
    tickRow.distribution = UIStackViewDistributionFillEqually;
    [self.timelineStack addArrangedSubview:tickRow];
    NSMutableArray *legendItems = [NSMutableArray array];
    NSArray *legendNames = @[@"正常", @"加班", @"休假"];
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = colors[i]; dot.layer.cornerRadius = 2;
        [dot.widthAnchor constraintEqualToConstant:8].active = YES;
        [dot.heightAnchor constraintEqualToConstant:8].active = YES;
        UILabel *l = GSLabel([NSString stringWithFormat:@"%@ %@H", legendNames[i], GSNum([vals[i] doubleValue])], GSFont(9, UIFontWeightRegular), GSColorHex(@"#667085"));
        [legendItems addObject:GSStack(@[dot, l], UILayoutConstraintAxisHorizontal, 3)];
    }
    [self.timelineStack addArrangedSubview:GSStack(legendItems, UILayoutConstraintAxisHorizontal, 12)];
}
- (void)prevMonth { [self changeMonth:-1]; }
- (void)nextMonth { [self changeMonth:1]; }
- (void)changeMonth:(NSInteger)delta {
    NSDateComponents *c = GSMonthAdd(self.year, self.month, delta);
    self.year = c.year; self.month = c.month;
    self.selectedDate = [NSString stringWithFormat:@"%04ld-%02ld-01", (long)self.year, (long)self.month];
    GSHaptic();
    [self reload];
}
- (void)primaryTapped {
    if ([[GSStore shared] recordForDate:self.selectedDate]) [self goToday];
    else [self openEditor];
}
- (void)goToday {
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    self.selectedDate = GSKeyFromDate(now);
    self.year = [cal component:NSCalendarUnitYear fromDate:now];
    self.month = [cal component:NSCalendarUnitMonth fromDate:now];
    GSHaptic();
    [self reload];
}
- (void)openBatch {
    GSBatchViewController *b = [[GSBatchViewController alloc] initWithStartDate:self.selectedDate endDate:self.selectedDate];
    b.onSaved = ^(NSInteger count) { [self reload]; };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:b];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)deleteCurrentRecord {
    NSDictionary *rec = [[GSStore shared] recordForDate:self.selectedDate];
    if (!rec) return;
    NSString *title = [NSString stringWithFormat:@"删除 %@ 的工时？", self.selectedDate];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:@"删除后这条记录和补贴/扣款都会移除。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
        [[GSStore shared] removeRecordForDate:self.selectedDate];
        [self reload];
        GSToast(@"已删除当前工时");
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)openEditor {
    GSEditorViewController *e = [[GSEditorViewController alloc] initWithDate:self.selectedDate];
    e.onSaved = ^{ [self reload]; };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:e];
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)rebuildDayCard {
    for (UIView *v in self.dayCard.subviews) [v removeFromSuperview];
    NSDictionary *rec = [[GSStore shared] recordForDate:self.selectedDate];
    NSDate *d = GSDateFromKey(self.selectedDate);
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    UILabel *date = GSLabel([NSString stringWithFormat:@"%02ld-%02ld", (long)[cal component:NSCalendarUnitMonth fromDate:d], (long)[cal component:NSCalendarUnitDay fromDate:d]], GSFont(19, UIFontWeightBold), GSColorHex(@"#101828"));
    UILabel *lunar = GSLabel([@"农 " stringByAppendingString:GSLunarFull(d)], GSFont(11, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UILabel *pay = GSLabel(GSMoney([[GSStore shared] dayPay:rec]), GSFont(22, UIFontWeightBold), GSColorHex(@"#B45309"));
    UILabel *spacer = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *head = GSStack(@[date, lunar, spacer, pay], UILayoutConstraintAxisHorizontal, 6);
    head.alignment = UIStackViewAlignmentLastBaseline;
    head.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dayCard addSubview:head];
    [NSLayoutConstraint activateConstraints:@[
        [head.topAnchor constraintEqualToAnchor:self.dayCard.topAnchor constant:18],
        [head.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
        [head.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18]
    ]];
    if (!rec) {
        NSString *plan = [[GSStore shared] planForDate:self.selectedDate];
        NSString *planName = plan ? [[GSStore shared] classWithId:plan][@"name"] : nil;
        NSString *emptyText = planName.length ? [NSString stringWithFormat:@"排班 · %@\n点这里或右下角记一笔", planName] : @"未记录工时\n点这里或右下角记一笔";
        UILabel *empty = GSLabel(emptyText, GSFont(13, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        empty.numberOfLines = 2; empty.textAlignment = NSTextAlignmentCenter;
        empty.translatesAutoresizingMaskIntoConstraints = NO;
        [self.dayCard addSubview:empty];
        [NSLayoutConstraint activateConstraints:@[
            [empty.topAnchor constraintEqualToAnchor:head.bottomAnchor constant:24],
            [empty.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
            [empty.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18],
            [empty.bottomAnchor constraintEqualToAnchor:self.dayCard.bottomAnchor constant:-28]
        ]];
        return;
    }
    NSDictionary *cls = [[GSStore shared] classWithId:rec[@"classId"]];
    NSString *kind = rec[@"type"] ?: GSDayKind(self.selectedDate);
    UILabel *sub = GSLabel([NSString stringWithFormat:@"%@   %@   %@", cls[@"name"] ?: @"未选班次", GSKindName(kind), [[GSStore shared] projectWithId:rec[@"projectId"]][@"name"]], GSFont(13, UIFontWeightMedium), GSColorHex(@"#667085"));
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dayCard addSubview:sub];
    UIView *line = GSLine(); line.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dayCard addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [sub.topAnchor constraintEqualToAnchor:head.bottomAnchor constant:12],
        [sub.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
        [sub.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18],
        [line.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:12],
        [line.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
        [line.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18],
        [line.heightAnchor constraintEqualToConstant:1]
    ]];
    UIView *last = line;
    NSArray *types = @[@"zb", @"jb", @"zm", @"jj"];
    NSArray *names = @[@"正班", @"加班", @"周末", @"节假"];
    NSArray *icons = @[@"person.fill", @"clock.fill", @"sun.max.fill", @"flag.fill"];
    NSArray *bgs = @[@"#E8F0FF", @"#FFF4E5", @"#FFF0F0", @"#F3EEFF"];
    NSArray *fgs = @[GSThemeHexValue(), @"#B54708", @"#B42318", @"#6941C6"];
    for (NSInteger i = 0; i < 4; i++) {
        id rawWork = rec[@"work"];
        NSDictionary *w = [rawWork isKindOfClass:[NSDictionary class]] ? rawWork : @{};
        double h = [w[types[i]] doubleValue];
        if (h <= 0) continue;
        UIView *ico = [[UIView alloc] init];
        ico.backgroundColor = i == 0 ? GSThemeSoftColor() : GSColorHex(bgs[i]); ico.layer.cornerRadius = 9;
        UIImageView *iv = [[UIImageView alloc] initWithImage:GSIcon(icons[i], 15)];
        iv.tintColor = GSColorHex(fgs[i]); iv.contentMode = UIViewContentModeCenter;
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        [ico addSubview:iv];
        [NSLayoutConstraint activateConstraints:@[[iv.centerXAnchor constraintEqualToAnchor:ico.centerXAnchor], [iv.centerYAnchor constraintEqualToAnchor:ico.centerYAnchor]]];
        UILabel *n = GSLabel(names[i], GSFont(15, UIFontWeightSemibold), GSColorHex(@"#101828"));
        UILabel *hv = GSLabel([NSString stringWithFormat:@"%@H", GSNum(h)], GSFont(14, UIFontWeightBold), GSThemeColor());
        UILabel *mv = GSLabel(GSMoney(h * [[GSStore shared] rateForProject:rec[@"projectId"] type:types[i]]), GSFont(15, UIFontWeightBold), i == 0 ? GSColorHex(@"#101828") : GSColorHex(@"#B45309"));
        UILabel *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
        UIStackView *row = GSStack(@[ico, n, hv, sp, mv], UILayoutConstraintAxisHorizontal, 10);
        row.alignment = UIStackViewAlignmentCenter;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [self.dayCard addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [ico.widthAnchor constraintEqualToConstant:30], [ico.heightAnchor constraintEqualToConstant:30],
            [row.topAnchor constraintEqualToAnchor:last.bottomAnchor constant:10],
            [row.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
            [row.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18]
        ]];
        last = row;
    }
    id rawBT = rec[@"bt"];
    if ([rawBT isKindOfClass:[NSArray class]] && [rawBT count]) {
        UILabel *btTitle = GSLabel(@"补扣明细", GSFont(13, UIFontWeightMedium), GSColorHex(@"#667085"));
        btTitle.translatesAutoresizingMaskIntoConstraints = NO;
        [self.dayCard addSubview:btTitle];
        [NSLayoutConstraint activateConstraints:@[
            [btTitle.topAnchor constraintEqualToAnchor:last.bottomAnchor constant:14],
            [btTitle.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
            [btTitle.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18]
        ]];
        last = btTitle;
        for (NSDictionary *b in rawBT) {
            if (![b isKindOfClass:[NSDictionary class]]) continue;
            double bm = [b[@"money"] doubleValue];
            if (fabs(bm) < 0.001) continue;
            UILabel *name = GSLabel(b[@"name"] ?: @"补扣", GSFont(13, UIFontWeightSemibold), GSColorHex(@"#344054"));
            UILabel *source = GSLabel([b[@"auto"] boolValue] ? @"自动补助" : ([b[@"note"] length] ? b[@"note"] : @"手动添加"), GSFont(9, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
            UIStackView *left = GSStack(@[name, source], UILayoutConstraintAxisVertical, 1);
            UILabel *mv = GSLabel([NSString stringWithFormat:@"%@%@", bm > 0 ? @"+" : @"-", GSMoney(fabs(bm))], GSFont(13, UIFontWeightBold), bm > 0 ? GSColorHex(@"#067647") : GSColorHex(@"#B42318"));
            UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
            UIStackView *row = GSStack(@[left, sp, mv], UILayoutConstraintAxisHorizontal, 8);
            row.alignment = UIStackViewAlignmentCenter;
            row.translatesAutoresizingMaskIntoConstraints = NO;
            [self.dayCard addSubview:row];
            [NSLayoutConstraint activateConstraints:@[
                [row.topAnchor constraintEqualToAnchor:last.bottomAnchor constant:7],
                [row.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
                [row.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18]
            ]];
            last = row;
        }
    }
    if ([rec[@"note"] length] > 0) {
        UILabel *note = GSLabel(rec[@"note"], GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        note.numberOfLines = 2;
        note.translatesAutoresizingMaskIntoConstraints = NO;
        [self.dayCard addSubview:note];
        [NSLayoutConstraint activateConstraints:@[
            [note.topAnchor constraintEqualToAnchor:last.bottomAnchor constant:10],
            [note.leadingAnchor constraintEqualToAnchor:self.dayCard.leadingAnchor constant:18],
            [note.trailingAnchor constraintEqualToAnchor:self.dayCard.trailingAnchor constant:-18]
        ]];
        last = note;
    }
    [last.bottomAnchor constraintEqualToAnchor:self.dayCard.bottomAnchor constant:-78].active = YES;
}
@end
