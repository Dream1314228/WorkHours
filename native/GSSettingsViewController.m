#import "GSSettingsViewController.h"
#import "GSComponents.h"
#import "GSStore.h"
#import "GSProjectEditViewController.h"
#import "GSReminder.h"

@interface GSSettingsViewController ()
@property (nonatomic, copy) NSString *page;
@property (nonatomic, strong) UIView *statusBg;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight, *statusHeight;
@property (nonatomic, copy) NSString *defClass;
@property (nonatomic, strong) NSDate *periodStart, *periodEnd;
@end
@implementation GSSettingsViewController
- (instancetype)initWithPage:(NSString *)page {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _page = [page copy]; _defClass = [GSStore shared].settings[@"currentClass"]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
    self.statusBg = [[UIView alloc] init];
    self.statusBg.backgroundColor = UIColor.clearColor;
    self.statusBg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusBg];
    self.header = [[GSGradientView alloc] init];
    self.header.colors = @[GSThemeColor(), GSThemeDarkColor()];
    self.header.translatesAutoresizingMaskIntoConstraints = NO;
    GSAddHeaderOrbs(self.header);
    GSApplyHeaderCorners(self.header);
    [self.view addSubview:self.header];
    self.titleLabel = GSLabel([self titleForPage], GSFont(17, UIFontWeightSemibold), UIColor.whiteColor);
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:self.titleLabel];
    UIButton *back = GSIconButton(@"chevron.left", UIColor.whiteColor, 19);
    back.translatesAutoresizingMaskIntoConstraints = NO;
    [back addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:back];
    self.scroll = [[UIScrollView alloc] init];
    self.scroll.backgroundColor = UIColor.clearColor;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0, 40, 0);
    [self.view addSubview:self.scroll];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 12;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    self.statusBg.hidden = YES;
    self.statusHeight = [self.statusBg.heightAnchor constraintEqualToConstant:64];
    self.headerHeight = [self.header.heightAnchor constraintEqualToConstant:110];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusBg.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.statusBg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.statusBg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.statusHeight,
        [self.header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.headerHeight,
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.header.centerXAnchor],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.header.bottomAnchor constant:-12],
        [back.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:16],
        [back.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [back.widthAnchor constraintEqualToConstant:34], [back.heightAnchor constraintEqualToConstant:34],
        [self.scroll.topAnchor constraintEqualToAnchor:self.header.bottomAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:16],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-40]
    ]];
    [self.view bringSubviewToFront:self.header];
    [self reload];
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    CGFloat top = self.view.safeAreaInsets.top;
    self.statusHeight.constant = top;
    self.headerHeight.constant = top + 52;
    self.header.startY = top / MAX(1, self.headerHeight.constant);
}
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
}
- (void)back { [self.navigationController popViewControllerAnimated:YES]; }
- (NSString *)titleForPage {
    if ([self.page isEqual:@"record"]) return @"记录设置";
    if ([self.page isEqual:@"salary"] || [self.page isEqual:@"projects"]) return @"薪资与项目";
    if ([self.page isEqual:@"classes"]) return @"班次管理";
    if ([self.page isEqual:@"period"]) return @"考勤周期";
    if ([self.page isEqual:@"software"]) return @"软件设置";
    return @"设置";
}
- (GSCardView *)card:(NSArray<UIView *> *)views {
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *v = [[UIStackView alloc] init];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 0; v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    for (NSInteger i = 0; i < (NSInteger)views.count; i++) {
        [v addArrangedSubview:views[i]];
        if (i < (NSInteger)views.count - 1) {
            UIView *line = GSLine(); [line.heightAnchor constraintEqualToConstant:1].active = YES;
            [v addArrangedSubview:line];
        }
    }
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:12], [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16], [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12]
    ]];
    return card;
}
- (UIView *)row:(NSString *)title value:(NSString *)value action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.backgroundColor = UIColor.clearColor;
    UILabel *l = GSLabel(title, GSFont(15, UIFontWeightRegular), GSColorHex(@"#101828"));
    UILabel *v = GSLabel(value, GSFont(13, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    v.textAlignment = NSTextAlignmentRight;
    UIImageView *c = [[UIImageView alloc] initWithImage:GSIcon(@"chevron.right", 11)];
    c.tintColor = GSColorHex(@"#667085");
    for (UIView *x in @[l, v, c]) { x.translatesAutoresizingMaskIntoConstraints = NO; [b addSubview:x]; }
    [NSLayoutConstraint activateConstraints:@[
        [b.heightAnchor constraintEqualToConstant:52],
        [l.leadingAnchor constraintEqualToAnchor:b.leadingAnchor], [l.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [v.trailingAnchor constraintEqualToAnchor:c.leadingAnchor constant:-4], [v.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [c.trailingAnchor constraintEqualToAnchor:b.trailingAnchor], [c.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [c.widthAnchor constraintEqualToConstant:12], [c.heightAnchor constraintEqualToConstant:12]
    ]];
    if (action) [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UIView *)switchRow:(NSString *)title sub:(NSString *)sub key:(NSString *)key tag:(NSInteger)tag {
    UIView *row = [[UIView alloc] init];
    UILabel *l = GSLabel(title, GSFont(15, UIFontWeightRegular), GSColorHex(@"#101828"));
    UILabel *s = GSLabel(sub ?: @"", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = GSThemeColor();
    sw.on = [[GSStore shared].settings[key] boolValue]; sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    for (UIView *x in @[l, s, sw]) { x.translatesAutoresizingMaskIntoConstraints = NO; [row addSubview:x]; }
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:sub ? 62 : 52],
        [l.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [l.topAnchor constraintEqualToAnchor:row.topAnchor constant:sub ? 11 : 0],
        [s.leadingAnchor constraintEqualToAnchor:l.leadingAnchor], [s.topAnchor constraintEqualToAnchor:l.bottomAnchor constant:2],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
    if (!sub) [l.centerYAnchor constraintEqualToAnchor:row.centerYAnchor].active = YES;
    return row;
}
- (UILabel *)section:(NSString *)text {
    UILabel *l = GSLabel(text, GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    l.numberOfLines = 0;
    l.tag = 900;
    return l;
}
- (void)reload {
    for (UIView *v in self.stack.arrangedSubviews) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
    if ([self.page isEqual:@"record"]) [self buildRecord];
    else if ([self.page isEqual:@"software"]) [self buildSoftware];
    else if ([self.page isEqual:@"salary"] || [self.page isEqual:@"projects"]) [self buildProjects:YES];
    else if ([self.page isEqual:@"classes"]) [self buildClasses];
    else if ([self.page isEqual:@"period"]) [self buildPeriod];
    GSAnimateStack(self.stack);
}
- (NSString *)periodTitle:(NSInteger)day {
    if (day == 1) return @"每月 1 号起算 · 1号 - 月底";
    return [NSString stringWithFormat:@"每月 %ld 号起算 · %ld号 - 下月%ld号", (long)day, (long)day, (long)(day - 1)];
}
- (void)buildRecord {
    GSStore *store = [GSStore shared];
    NSMutableDictionary *s = store.settings;
    [self.stack addArrangedSubview:[self section:@"考勤计算周期"]];
    NSInteger periodDay = [s[@"period"] integerValue];
    if (periodDay < 1 || periodDay > 29) periodDay = 26;
    UIButton *period = [UIButton buttonWithType:UIButtonTypeCustom];
    [period setTitle:[self periodTitle:periodDay] forState:UIControlStateNormal];
    [period setTitleColor:GSColorHex(@"#101828") forState:UIControlStateNormal];
    period.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    period.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    period.backgroundColor = GSColorHex(@"#F5F7FA"); period.layer.cornerRadius = 12; period.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    [period.heightAnchor constraintEqualToConstant:46].active = YES;
    NSMutableArray *periodActions = [NSMutableArray array];
    for (NSInteger d = 1; d <= 29; d++) {
        NSString *title = [self periodTitle:d];
        UIAction *act = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction *a) {
            [GSStore shared].settings[@"period"] = @(d);
            [[GSStore shared] save];
            [self reload]; GSToast(@"已切换考勤周期");
        }];
        if (d == periodDay) act.state = UIMenuElementStateOn;
        [periodActions addObject:act];
    }
    period.showsMenuAsPrimaryAction = YES;
    period.menu = [UIMenu menuWithTitle:@"每月起算日" children:periodActions];
    GSCardView *pc = [[GSCardView alloc] init];
    UILabel *pl = GSLabel(@"原版 29 档：每月 1~29 号起算，命中自定义周期时优先用自定义区间", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82")); pl.numberOfLines = 0;
    UIStackView *pv = GSStack(@[period, pl], UILayoutConstraintAxisVertical, 8);
    pv.translatesAutoresizingMaskIntoConstraints = NO; [pc addSubview:pv];
    [NSLayoutConstraint activateConstraints:@[
        [pv.topAnchor constraintEqualToAnchor:pc.topAnchor constant:16], [pv.leadingAnchor constraintEqualToAnchor:pc.leadingAnchor constant:16],
        [pv.trailingAnchor constraintEqualToAnchor:pc.trailingAnchor constant:-16], [pv.bottomAnchor constraintEqualToAnchor:pc.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:pc];
    [self.stack addArrangedSubview:[self card:@[[self row:@"自定义考勤周期" value:[NSString stringWithFormat:@"%ld 段", (long)[s[@"customPeriods"] count]] action:@selector(openPeriod)]]]];

    NSInteger payday = [s[@"payday"] integerValue];
    if (payday < 0 || payday > 31) payday = 0;
    [self.stack addArrangedSubview:[self section:@"发薪日"]];
    UIButton *payBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [payBtn setTitle:(payday > 0 ? [NSString stringWithFormat:@"每月 %ld 日", (long)payday] : @"未设置") forState:UIControlStateNormal];
    [payBtn setTitleColor:GSColorHex(@"#101828") forState:UIControlStateNormal];
    payBtn.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    payBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    payBtn.backgroundColor = GSColorHex(@"#F5F7FA");
    payBtn.layer.cornerRadius = 12;
    payBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    [payBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    NSMutableArray *payActions = [NSMutableArray array];
    UIAction *none = [UIAction actionWithTitle:@"不设置" image:nil identifier:nil handler:^(__kindof UIAction *a) {
        [GSStore shared].settings[@"payday"] = @0;
        [[GSStore shared] save];
        [self reload]; GSToast(@"已关闭发薪日标记");
    }];
    if (payday == 0) none.state = UIMenuElementStateOn;
    [payActions addObject:none];
    for (NSInteger d = 1; d <= 31; d++) {
        UIAction *act = [UIAction actionWithTitle:[NSString stringWithFormat:@"每月 %ld 日", (long)d] image:nil identifier:nil handler:^(__kindof UIAction *a) {
            [GSStore shared].settings[@"payday"] = @(d);
            [[GSStore shared] save];
            [self reload]; GSToast(@"发薪日已更新");
        }];
        if (d == payday) act.state = UIMenuElementStateOn;
        [payActions addObject:act];
    }
    payBtn.showsMenuAsPrimaryAction = YES;
    payBtn.menu = [UIMenu menuWithTitle:@"每月发薪日" children:payActions];
    UILabel *payNote = GSLabel(@"发薪日当天：日号变金色，左上角显示「薪」，底部金条常显；记录工时后工时数字也变金色。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    payNote.numberOfLines = 0;
    GSCardView *payCard = [[GSCardView alloc] init];
    UIStackView *payStack = GSStack(@[payBtn, payNote], UILayoutConstraintAxisVertical, 8);
    payStack.translatesAutoresizingMaskIntoConstraints = NO;
    [payCard addSubview:payStack];
    [NSLayoutConstraint activateConstraints:@[
        [payStack.topAnchor constraintEqualToAnchor:payCard.topAnchor constant:16],
        [payStack.leadingAnchor constraintEqualToAnchor:payCard.leadingAnchor constant:16],
        [payStack.trailingAnchor constraintEqualToAnchor:payCard.trailingAnchor constant:-16],
        [payStack.bottomAnchor constraintEqualToAnchor:payCard.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:payCard];

    [self.stack addArrangedSubview:[self section:@"每周工作日"]];
    UISegmentedControl *week = [[UISegmentedControl alloc] initWithItems:@[@"周一", @"周日"]];
    week.selectedSegmentIndex = [s[@"weekStart"] integerValue] == 0 ? 1 : 0;
    week.selectedSegmentTintColor = GSThemeColor(); week.tag = 104;
    [week addTarget:self action:@selector(weekChanged:) forControlEvents:UIControlEventValueChanged];
    [self.stack addArrangedSubview:[self card:@[week]]];

    [self.stack addArrangedSubview:[self card:@[
        [self switchRow:@"夜班模式" sub:@"默认选中昨天日期" key:@"nightMode" tag:100],
        [self switchRow:@"日补扣自动记录" sub:@"记录工时时自动带入白班/夜班补助" key:@"autoBonus" tag:101]
    ]]];

    [self.stack addArrangedSubview:[self section:@"班次自动补助"]];
    NSMutableArray *allowRows = [NSMutableArray array];
    NSArray *allowTitles = @[@"白班补助", @"夜班补助"];
    NSArray *allowKeys = @[@"dayAllowance", @"nightAllowance"];
    for (NSInteger i = 0; i < 2; i++) {
        UIView *row = [[UIView alloc] init];
        UILabel *l = GSLabel(allowTitles[i], GSFont(14, UIFontWeightRegular), GSColorHex(@"#101828"));
        UITextField *tf = [[UITextField alloc] init];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.font = GSFont(14, UIFontWeightSemibold);
        tf.textColor = GSThemeColor();
        tf.textAlignment = NSTextAlignmentRight;
        double val = [s[allowKeys[i]] doubleValue];
        tf.text = GSNum(MAX(0, val));
        tf.tag = 601 + i;
        [tf addTarget:self action:@selector(allowanceChanged:) forControlEvents:UIControlEventEditingChanged];
        [tf addTarget:self action:@selector(allowanceEnded:) forControlEvents:UIControlEventEditingDidEnd];
        for (UIView *x in @[l, tf]) { x.translatesAutoresizingMaskIntoConstraints = NO; [row addSubview:x]; }
        [NSLayoutConstraint activateConstraints:@[
            [row.heightAnchor constraintEqualToConstant:48],
            [l.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [l.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [tf.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [tf.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [tf.widthAnchor constraintEqualToConstant:100], [tf.heightAnchor constraintEqualToConstant:36]
        ]];
        [allowRows addObject:row];
    }
    UILabel *allowNote = GSLabel(@"按班次名匹配：白班/早班加白班补助，中班/晚班/夜班加夜班补助；填 0 即关闭该类补助，并清除已有的自动补助。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82")); allowNote.numberOfLines = 0;
    [allowRows addObject:allowNote];
    UIStackView *allowStack = GSStack(allowRows, UILayoutConstraintAxisVertical, 8);
    [self.stack addArrangedSubview:[self card:@[allowStack]]];

    [self.stack addArrangedSubview:[self section:@"年假"]];
    double annualDays = MAX(0, [s[@"annualLeaveDays"] doubleValue]);
    UILabel *annualValue = GSLabel([NSString stringWithFormat:@"%@ 天", GSNum(annualDays)], GSFont(15, UIFontWeightBold), GSThemeColor());
    annualValue.tag = 700; annualValue.textAlignment = NSTextAlignmentRight;
    UILabel *annualTitle = GSLabel(@"年假额度", GSFont(14, UIFontWeightSemibold), GSColorHex(@"#101828"));
    UIView *annualSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *annualHead = GSStack(@[annualTitle, annualSp, annualValue], UILayoutConstraintAxisHorizontal, 8);
    UISlider *annualSlider = [[UISlider alloc] init];
    annualSlider.minimumValue = 0; annualSlider.maximumValue = 30; annualSlider.value = annualDays;
    annualSlider.continuous = YES; annualSlider.tag = 701;
    annualSlider.minimumTrackTintColor = GSThemeColor();
    annualSlider.maximumTrackTintColor = GSColorHex(@"#D0D5DD");
    annualSlider.thumbTintColor = GSThemeColor();
    [annualSlider addTarget:self action:@selector(annualLeaveChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *annualHint = GSLabel(@"年假每年会变，直接拖动调整；薪假按 8H/天从年假余额里扣。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    annualHint.numberOfLines = 0;
    UIStackView *annualStack = GSStack(@[annualHead, annualSlider, annualHint], UILayoutConstraintAxisVertical, 6);
    annualStack.translatesAutoresizingMaskIntoConstraints = NO;
    GSCardView *annualCard = [[GSCardView alloc] init];
    [annualCard addSubview:annualStack];
    [NSLayoutConstraint activateConstraints:@[
        [annualStack.topAnchor constraintEqualToAnchor:annualCard.topAnchor constant:16],
        [annualStack.leadingAnchor constraintEqualToAnchor:annualCard.leadingAnchor constant:16],
        [annualStack.trailingAnchor constraintEqualToAnchor:annualCard.trailingAnchor constant:-16],
        [annualStack.bottomAnchor constraintEqualToAnchor:annualCard.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:annualCard];

    [self.stack addArrangedSubview:[self section:@"打卡记录方式"]];
    UISegmentedControl *mode = [[UISegmentedControl alloc] initWithItems:@[@"时长记录", @"时间记录"]];
    mode.selectedSegmentIndex = [s[@"recordMode"] isEqual:@"time"] ? 1 : 0;
    mode.selectedSegmentTintColor = GSThemeColor(); mode.tag = 102;
    [mode addTarget:self action:@selector(recordModeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.stack addArrangedSubview:[self card:@[mode]]];

    [self.stack addArrangedSubview:[self section:@"配置默认时长"]];
    NSArray *classes = store.classes;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *c in classes) [names addObject:c[@"name"]];
    UISegmentedControl *classSeg = [[UISegmentedControl alloc] initWithItems:names];
    NSInteger idx = 0;
    for (NSInteger i = 0; i < (NSInteger)classes.count; i++) if ([classes[i][@"id"] isEqual:self.defClass]) idx = i;
    classSeg.selectedSegmentIndex = idx; classSeg.selectedSegmentTintColor = GSThemeColor(); classSeg.tag = 105;
    [classSeg addTarget:self action:@selector(defClassChanged:) forControlEvents:UIControlEventValueChanged];
    NSMutableArray *rows = [NSMutableArray arrayWithObject:classSeg];
    NSDictionary *def = [store defaultWorkForClass:self.defClass];
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj", @"rjgz"];
    NSArray *titles = @[@"正班", @"加班", @"周末", @"节假", @"日结"];
    for (NSInteger i = 0; i < 5; i++) {
        UIView *row = [[UIView alloc] init];
        UILabel *n = GSLabel(titles[i], GSFont(14, UIFontWeightRegular), GSColorHex(@"#101828"));
        UILabel *v = GSLabel([NSString stringWithFormat:@"%@%@", GSNum([def[keys[i]] doubleValue]), i == 4 ? @"元" : @"H"], GSFont(13, UIFontWeightBold), GSThemeColor());
        v.tag = 300 + i;
        UIStepper *st = [[UIStepper alloc] init];
        st.minimumValue = 0; st.maximumValue = i == 4 ? 100000 : 24; st.stepValue = i == 4 ? 10 : 0.5;
        st.value = [def[keys[i]] doubleValue]; st.tag = 200 + i;
        [st addTarget:self action:@selector(defStepper:) forControlEvents:UIControlEventValueChanged];
        for (UIView *x in @[n, v, st]) { x.translatesAutoresizingMaskIntoConstraints = NO; [row addSubview:x]; }
        [NSLayoutConstraint activateConstraints:@[
            [row.heightAnchor constraintEqualToConstant:48],
            [n.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [n.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [st.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [st.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [v.trailingAnchor constraintEqualToAnchor:st.leadingAnchor constant:-6], [v.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
        ]];
        [rows addObject:row];
    }
    UIStackView *defStack = GSStack(rows, UILayoutConstraintAxisVertical, 8);
    [self.stack addArrangedSubview:[self card:@[defStack]]];
}
- (void)buildSoftware {
    NSMutableDictionary *s = [GSStore shared].settings;
    [self.stack addArrangedSubview:[self section:@"记录提醒"]];
    UIView *reminderSwitch = [self switchRow:@"每天提醒" sub:@"到点提醒补记当天工时" key:@"reminderEnabled" tag:107];
    NSInteger rh = [s[@"reminderHour"] integerValue]; NSInteger rm = [s[@"reminderMinute"] integerValue];
    NSDateComponents *rc = [NSDateComponents new]; rc.hour = MAX(0, MIN(23, rh)); rc.minute = MAX(0, MIN(59, rm));
    NSDate *rdate = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] dateFromComponents:rc] ?: [NSDate date];
    UIDatePicker *timePicker = [[UIDatePicker alloc] init];
    timePicker.datePickerMode = UIDatePickerModeTime;
    timePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    timePicker.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    timePicker.backgroundColor = GSColorHex(@"#F7F9FC");
    timePicker.tintColor = GSThemeColor();
    timePicker.layer.cornerRadius = 12;
    timePicker.clipsToBounds = YES;
    timePicker.date = rdate;
    timePicker.tag = 108;
    timePicker.minuteInterval = 5;
    [timePicker addTarget:self action:@selector(reminderTimeChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *reminderNote = GSLabel(@"关闭开关会取消本地通知；通知只在系统本地触发，不上传数据。请允许通知权限。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    reminderNote.numberOfLines = 0;
    UILabel *timeTitle = GSLabel(@"提醒时间", GSFont(12, UIFontWeightMedium), GSColorHex(@"#344054"));
    UIStackView *reminderStack = GSStack(@[reminderSwitch, timeTitle, timePicker, reminderNote], UILayoutConstraintAxisVertical, 8);
    [self.stack addArrangedSubview:[self card:@[reminderStack]]];

    [self.stack addArrangedSubview:[self section:@"日历与班次"]];
    UISegmentedControl *week = [[UISegmentedControl alloc] initWithItems:@[@"周一", @"周日"]];
    week.selectedSegmentIndex = [s[@"weekStart"] integerValue] == 0 ? 1 : 0;
    week.tag = 104; week.selectedSegmentTintColor = GSThemeColor();
    [week addTarget:self action:@selector(weekChanged:) forControlEvents:UIControlEventValueChanged];
    UISegmentedControl *display = [[UISegmentedControl alloc] initWithItems:@[@"图标", @"文本", @"不显示"]];
    display.tag = 106; display.selectedSegmentTintColor = GSThemeColor();
    if ([s[@"classDisplay"] isEqual:@"text"]) display.selectedSegmentIndex = 1;
    else if ([s[@"classDisplay"] isEqual:@"hide"]) display.selectedSegmentIndex = 2;
    [display addTarget:self action:@selector(classDisplayChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *displayLabel = GSLabel(@"班次标记", GSFont(11, UIFontWeightMedium), GSColorHex(@"#5D6B82"));
    UILabel *displayNote = GSLabel(@"图标：太阳/月亮；文本：白班/夜班；不显示：只留日期。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    displayNote.numberOfLines = 0;
    UIStackView *calOpts = GSStack(@[week, displayLabel, display, displayNote], UILayoutConstraintAxisVertical, 10);
    [self.stack addArrangedSubview:[self card:@[calOpts]]];
    NSMutableDictionary *st = [GSStore shared].settings;
    double radius = [st[@"headerRadius"] doubleValue];
    if (radius < 0) radius = 0; if (radius > 40) radius = 40;
    UILabel *radiusTitle = GSLabel(@"顶部色块圆角", GSFont(14, UIFontWeightSemibold), GSColorHex(@"#101828"));
    UILabel *radiusValue = GSLabel([NSString stringWithFormat:@"%.0f pt", radius], GSFont(13, UIFontWeightSemibold), GSThemeColor());
    radiusValue.tag = 810; radiusValue.textAlignment = NSTextAlignmentRight;
    UIView *radiusSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *radiusHead = GSStack(@[radiusTitle, radiusSp, radiusValue], UILayoutConstraintAxisHorizontal, 8);
    UISlider *radiusSlider = [[UISlider alloc] init];
    radiusSlider.minimumValue = 0; radiusSlider.maximumValue = 40; radiusSlider.value = radius;
    radiusSlider.continuous = NO;
    radiusSlider.minimumTrackTintColor = GSThemeColor(); radiusSlider.maximumTrackTintColor = GSColorHex(@"#D0D5DD");
    radiusSlider.thumbTintColor = GSThemeColor();
    [radiusSlider addTarget:self action:@selector(headerRadiusChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *radiusHint = GSLabel(@"只影响顶部颜色块的下方两个角；0 为直角。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    radiusHint.numberOfLines = 0;
    [self.stack addArrangedSubview:[self card:@[GSStack(@[radiusHead, radiusSlider, radiusHint], UILayoutConstraintAxisVertical, 8)]]];
    [self.stack addArrangedSubview:[self card:@[
        [self row:@"主题色彩" value:GSThemeNameValue() action:@selector(chooseTheme)],
        [self row:@"关于" value:@"工时记录 2.9.1" action:nil]
    ]]];
    [self.stack addArrangedSubview:[self section:@"数据只存在本机；登录、VIP、广告、云同步不包含"]];
}
- (void)headerRadiusChanged:(UISlider *)slider {
    double v = round(slider.value);
    slider.value = v;
    [GSStore shared].settings[@"headerRadius"] = @(v);
    [[GSStore shared] save];
    UILabel *value = (UILabel *)[self.stack viewWithTag:810];
    if (value) value.text = [NSString stringWithFormat:@"%.0f pt", v];
    [[NSNotificationCenter defaultCenter] postNotificationName:GSHeaderRadiusDidChangeNotification object:nil];
}
- (void)chooseTheme {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"主题色彩" message:@"切换后会自动刷新界面" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *keys = GSThemeKeys(); NSArray *names = GSThemeNames();
    NSString *current = GSThemeKeyValue();
    for (NSInteger i = 0; i < (NSInteger)keys.count; i++) {
        NSString *key = keys[i];
        NSString *title = [NSString stringWithFormat:@"%@%@", [key isEqual:current] ? @"✓ " : @"", names[i]];
        [a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
            [GSStore shared].settings[@"theme"] = key;
            [[GSStore shared] save];
            GSSetThemeKey(key);
            [[NSNotificationCenter defaultCenter] postNotificationName:GSThemeDidChangeNotification object:nil];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}
- (void)annualLeaveChanged:(UISlider *)slider {
    double v = round(slider.value * 2.0) / 2.0;
    slider.value = v;
    [GSStore shared].settings[@"annualLeaveDays"] = @(v);
    [[GSStore shared] save];
    UILabel *vlabel = (UILabel *)[self.stack viewWithTag:700];
    if (vlabel) vlabel.text = [NSString stringWithFormat:@"%@ 天", GSNum(v)];
}
- (void)periodChanged:(UISegmentedControl *)s {
    [GSStore shared].settings[@"period"] = s.selectedSegmentIndex == 0 ? @1 : @26;
    [[GSStore shared] save]; GSToast(@"已切换");
}
- (void)weekChanged:(UISegmentedControl *)s {
    [GSStore shared].settings[@"weekStart"] = s.selectedSegmentIndex == 1 ? @0 : @1;
    [[GSStore shared] save]; GSToast(@"已切换");
}
- (void)recordModeChanged:(UISegmentedControl *)s {
    [GSStore shared].settings[@"recordMode"] = s.selectedSegmentIndex == 0 ? @"hour" : @"time";
    [[GSStore shared] save];
}
- (void)classDisplayChanged:(UISegmentedControl *)s {
    NSArray *v = @[@"icon", @"text", @"hide"];
    [GSStore shared].settings[@"classDisplay"] = v[s.selectedSegmentIndex];
    [[GSStore shared] save];
    GSToast(@"日历班次标记已更新");
}
- (void)allowanceChanged:(UITextField *)tf {
    NSString *key = tf.tag == 601 ? @"dayAllowance" : @"nightAllowance";
    [GSStore shared].settings[key] = @(MAX(0, tf.text.doubleValue));
    [[GSStore shared] save];
}
- (void)allowanceEnded:(UITextField *)tf {
    if (tf.text.doubleValue > 0) return;
    NSString *name = tf.tag == 601 ? @"白班补助" : @"夜班补助";
    NSInteger removed = [[GSStore shared] removeAutoAllowanceNamed:name];
    if (removed > 0) GSToast([NSString stringWithFormat:@"已关闭%@，并清除 %ld 条自动补助", name, (long)removed]);
}
- (void)switchChanged:(UISwitch *)sw {
    NSString *key = sw.tag == 100 ? @"nightMode" : (sw.tag == 107 ? @"reminderEnabled" : @"autoBonus");
    [GSStore shared].settings[key] = @(sw.on);
    [[GSStore shared] save];
    if (sw.tag == 107) {
        if (sw.on) [GSReminder requestAndSync]; else [GSReminder syncFromSettings];
    }
}
- (void)reminderTimeChanged:(UIDatePicker *)picker {
    NSDateComponents *c = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:picker.date];
    [GSStore shared].settings[@"reminderHour"] = @(c.hour);
    [GSStore shared].settings[@"reminderMinute"] = @(c.minute);
    [[GSStore shared] save];
    [GSReminder syncFromSettings];
}
- (void)defClassChanged:(UISegmentedControl *)s {
    NSArray *classes = [[GSStore shared] classes];
    if (s.selectedSegmentIndex < (NSInteger)classes.count) self.defClass = classes[s.selectedSegmentIndex][@"id"];
    NSDictionary *def = [[GSStore shared] defaultWorkForClass:self.defClass];
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj", @"rjgz"];
    for (NSInteger i = 0; i < 5; i++) {
        UIStepper *st = (UIStepper *)[self.stack viewWithTag:200 + i];
        UILabel *v = (UILabel *)[self.stack viewWithTag:300 + i];
        double val = [def[keys[i]] doubleValue];
        if (st) st.value = val;
        if (v) v.text = [NSString stringWithFormat:@"%@%@", GSNum(val), i == 4 ? @"元" : @"H"];
    }
}
- (void)defStepper:(UIStepper *)st {
    NSInteger i = st.tag - 200;
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj", @"rjgz"];
    [[GSStore shared] setClassDefault:self.defClass key:keys[i] value:st.value];
    UILabel *v = (UILabel *)[self.stack viewWithTag:300 + i];
    if (v) v.text = [NSString stringWithFormat:@"%@%@", GSNum(st.value), i == 4 ? @"元" : @"H"];
}
- (void)openPeriod {
    [self.navigationController pushViewController:[[GSSettingsViewController alloc] initWithPage:@"period"] animated:YES];
}
- (void)buildProjects:(BOOL)salary {
    NSArray *projects = [[GSStore shared] projects];
    NSString *current = [GSStore shared].settings[@"projectId"];
    for (NSInteger i = 0; i < (NSInteger)projects.count; i++) {
        NSDictionary *p = projects[i];
        GSCardView *card = [[GSCardView alloc] init];
        UILabel *name = GSLabel(p[@"name"], GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
        UILabel *base = GSLabel([NSString stringWithFormat:@"底薪 ¥%@", GSNum([p[@"base"] doubleValue])], GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        UIButton *edit = [UIButton buttonWithType:UIButtonTypeSystem];
        [edit setTitle:@"编辑" forState:UIControlStateNormal]; edit.titleLabel.font = GSFont(12, UIFontWeightSemibold); edit.tag = i;
        [edit setTitleColor:GSThemeColor() forState:UIControlStateNormal];
        edit.backgroundColor = GSThemeSoftColor(); edit.layer.cornerRadius = 10;
        [edit.widthAnchor constraintEqualToConstant:52].active = YES;
        [edit.heightAnchor constraintEqualToConstant:30].active = YES;
        [edit addTarget:self action:@selector(editProject:) forControlEvents:UIControlEventTouchUpInside];
        UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
        UIStackView *head = GSStack(@[name, base, sp, edit], UILayoutConstraintAxisHorizontal, 8);
        head.alignment = UIStackViewAlignmentCenter;
        NSDictionary *rates = p[@"rates"];
        UILabel *r1 = GSLabel([NSString stringWithFormat:@"正班 ¥%@/h", GSNum([rates[@"zb"] doubleValue])], GSFont(11, UIFontWeightRegular), GSColorHex(@"#667085"));
        UILabel *r2 = GSLabel([NSString stringWithFormat:@"加班 ¥%@/h", GSNum([rates[@"jb"] doubleValue])], GSFont(11, UIFontWeightRegular), GSColorHex(@"#667085"));
        UILabel *r3 = GSLabel([NSString stringWithFormat:@"周末 ¥%@/h", GSNum([rates[@"zm"] doubleValue])], GSFont(11, UIFontWeightRegular), GSColorHex(@"#667085"));
        UILabel *r4 = GSLabel([NSString stringWithFormat:@"节假 ¥%@/h", GSNum([rates[@"jj"] doubleValue])], GSFont(11, UIFontWeightRegular), GSColorHex(@"#667085"));
        UIStackView *row1 = GSStack(@[r1, r2], UILayoutConstraintAxisHorizontal, 8); row1.distribution = UIStackViewDistributionFillEqually;
        UIStackView *row2 = GSStack(@[r3, r4], UILayoutConstraintAxisHorizontal, 8); row2.distribution = UIStackViewDistributionFillEqually;
        NSMutableArray *views = [NSMutableArray arrayWithObjects:head, row1, row2, nil];
        if (salary) {
            UIButton *use = [UIButton buttonWithType:UIButtonTypeSystem];
            BOOL on = [current isEqual:p[@"id"]];
            [use setTitle:on ? @"当前项目" : @"设为当前" forState:UIControlStateNormal];
            use.titleLabel.font = GSFont(12, UIFontWeightSemibold); use.tag = i;
            use.backgroundColor = on ? GSThemeSoftColor() : GSColorHex(@"#F5F7FA");
            [use setTitleColor:GSThemeColor() forState:UIControlStateNormal];
            use.layer.cornerRadius = 12; [use.heightAnchor constraintEqualToConstant:34].active = YES;
            if (!on) [use addTarget:self action:@selector(setProject:) forControlEvents:UIControlEventTouchUpInside];
            [views addObject:use];
        }
        UIStackView *v = GSStack(views, UILayoutConstraintAxisVertical, 8);
        v.translatesAutoresizingMaskIntoConstraints = NO; [card addSubview:v];
        [NSLayoutConstraint activateConstraints:@[
            [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:14], [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
            [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14], [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
        ]];
        [self.stack addArrangedSubview:card];
    }
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setTitle:@"+ 新增项目" forState:UIControlStateNormal]; add.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    add.backgroundColor = GSThemeSoftColor(); add.layer.cornerRadius = 16;
    [add.heightAnchor constraintEqualToConstant:46].active = YES;
    [add addTarget:self action:@selector(addProject) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:add];
}
- (void)buildClasses {
    NSArray *classes = [[GSStore shared] classes];
    for (NSInteger i = 0; i < (NSInteger)classes.count; i++) {
        NSDictionary *c = classes[i];
        GSCardView *card = [[GSCardView alloc] init];
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = GSColorHex(c[@"color"]); dot.layer.cornerRadius = 6;
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *name = GSLabel(c[@"name"], GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
        UIButton *edit = [UIButton buttonWithType:UIButtonTypeSystem];
        [edit setTitle:@"编辑" forState:UIControlStateNormal]; edit.titleLabel.font = GSFont(12, UIFontWeightSemibold); edit.tag = i;
        [edit setTitleColor:GSThemeColor() forState:UIControlStateNormal];
        edit.backgroundColor = GSThemeSoftColor(); edit.layer.cornerRadius = 10;
        [edit.widthAnchor constraintEqualToConstant:52].active = YES;
        [edit.heightAnchor constraintEqualToConstant:30].active = YES;
        [edit addTarget:self action:@selector(editClass:) forControlEvents:UIControlEventTouchUpInside];
        UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
        UIStackView *row = GSStack(@[dot, name, sp, edit], UILayoutConstraintAxisHorizontal, 10);
        row.alignment = UIStackViewAlignmentCenter;
        row.translatesAutoresizingMaskIntoConstraints = NO; [card addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.topAnchor constraintEqualToAnchor:card.topAnchor constant:16], [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16], [row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
            [dot.widthAnchor constraintEqualToConstant:12], [dot.heightAnchor constraintEqualToConstant:12]
        ]];
        [self.stack addArrangedSubview:card];
    }
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setTitle:@"+ 新增班次" forState:UIControlStateNormal]; add.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    [add setTitleColor:GSThemeColor() forState:UIControlStateNormal];
    add.backgroundColor = GSThemeSoftColor(); add.layer.cornerRadius = 16;
    [add.heightAnchor constraintEqualToConstant:46].active = YES;
    [add addTarget:self action:@selector(addClass) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:add];
}
- (void)buildPeriod {
    NSMutableDictionary *s = [GSStore shared].settings;
    NSArray *periods = s[@"customPeriods"] ?: @[];
    NSMutableArray *rows = [NSMutableArray array];
    if (periods.count == 0) {
        [rows addObject:GSLabel(@"还没有自定义周期，默认按 26 号 - 下月 25 号", GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"))];
    }
    for (NSInteger i = 0; i < (NSInteger)periods.count; i++) {
        NSDictionary *p = periods[i];
        UILabel *l = GSLabel([NSString stringWithFormat:@"%@ → %@", p[@"start"], p[@"end"]], GSFont(13, UIFontWeightMedium), GSColorHex(@"#101828"));
        UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
        [del setTitle:@"删除" forState:UIControlStateNormal]; [del setTitleColor:GSColorHex(@"#B42318") forState:UIControlStateNormal];
        del.titleLabel.font = GSFont(12, UIFontWeightSemibold); del.tag = i;
        [del addTarget:self action:@selector(deletePeriod:) forControlEvents:UIControlEventTouchUpInside];
        UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
        UIStackView *row = GSStack(@[l, sp, del], UILayoutConstraintAxisHorizontal, 8);
        [rows addObject:row];
    }
    [self.stack addArrangedSubview:[self card:rows]];

    if (!self.periodStart) self.periodStart = [NSDate date];
    if (!self.periodEnd) self.periodEnd = [NSDate dateWithTimeIntervalSinceNow:30 * 86400];
    UIDatePicker *start = [[UIDatePicker alloc] init];
    start.datePickerMode = UIDatePickerModeDate; start.preferredDatePickerStyle = UIDatePickerStyleCompact;
    start.date = self.periodStart; start.tag = 401;
    [start addTarget:self action:@selector(periodDateChanged:) forControlEvents:UIControlEventValueChanged];
    UIDatePicker *end = [[UIDatePicker alloc] init];
    end.datePickerMode = UIDatePickerModeDate; end.preferredDatePickerStyle = UIDatePickerStyleCompact;
    end.date = self.periodEnd; end.tag = 402;
    [end addTarget:self action:@selector(periodDateChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *sl = GSLabel(@"开始", GSFont(12, UIFontWeightMedium), GSColorHex(@"#667085"));
    UILabel *el = GSLabel(@"结束", GSFont(12, UIFontWeightMedium), GSColorHex(@"#667085"));
    UIView *sr = [[UIView alloc] init];
    [sr addSubview:sl]; [sr addSubview:start];
    sl.translatesAutoresizingMaskIntoConstraints = NO; start.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [sl.leadingAnchor constraintEqualToAnchor:sr.leadingAnchor], [sl.centerYAnchor constraintEqualToAnchor:sr.centerYAnchor],
        [start.leadingAnchor constraintEqualToAnchor:sl.trailingAnchor constant:8], [start.trailingAnchor constraintEqualToAnchor:sr.trailingAnchor],
        [start.topAnchor constraintEqualToAnchor:sr.topAnchor], [start.bottomAnchor constraintEqualToAnchor:sr.bottomAnchor],
        [sr.heightAnchor constraintEqualToConstant:40]
    ]];
    UIView *er = [[UIView alloc] init];
    [er addSubview:el]; [er addSubview:end];
    el.translatesAutoresizingMaskIntoConstraints = NO; end.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [el.leadingAnchor constraintEqualToAnchor:er.leadingAnchor], [el.centerYAnchor constraintEqualToAnchor:er.centerYAnchor],
        [end.leadingAnchor constraintEqualToAnchor:el.trailingAnchor constant:8], [end.trailingAnchor constraintEqualToAnchor:er.trailingAnchor],
        [end.topAnchor constraintEqualToAnchor:er.topAnchor], [end.bottomAnchor constraintEqualToAnchor:er.bottomAnchor],
        [er.heightAnchor constraintEqualToConstant:40]
    ]];
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setTitle:@"保存这一段" forState:UIControlStateNormal]; add.titleLabel.font = GSFont(14, UIFontWeightBold);
    add.backgroundColor = GSThemeColor(); [add setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    add.layer.cornerRadius = 10; [add.heightAnchor constraintEqualToConstant:42].active = YES;
    [add addTarget:self action:@selector(addPeriod) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *form = GSStack(@[GSLabel(@"新增一段", GSFont(12, UIFontWeightMedium), GSColorHex(@"#5D6B82")), sr, er, add], UILayoutConstraintAxisVertical, 10);
    [self.stack addArrangedSubview:[self card:@[form]]];
    [self.stack addArrangedSubview:[self section:@"命中自定义周期时优先用它的起止日；没命中再按默认周期"]];
}
- (void)editProject:(UIButton *)b { [self editProjectAtIndex:b.tag]; }
- (void)addProject { [self editProjectAtIndex:-1]; }
- (void)editProjectAtIndex:(NSInteger)index {
    NSArray *projects = [GSStore shared].data[@"projects"];
    NSDictionary *p = index >= 0 && index < (NSInteger)projects.count ? projects[index] : nil;
    GSProjectEditViewController *e = [[GSProjectEditViewController alloc] initWithProject:p index:index];
    e.onSaved = ^{ [self reload]; };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:e];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)setProject:(UIButton *)b {
    NSArray *projects = [[GSStore shared] projects];
    if (b.tag >= 0 && b.tag < (NSInteger)projects.count) {
        [GSStore shared].settings[@"projectId"] = projects[b.tag][@"id"];
        [[GSStore shared] save]; [self reload]; GSToast(@"已切换项目");
    }
}
- (void)editClass:(UIButton *)b { [self editClassAtIndex:b.tag]; }
- (void)addClass { [self editClassAtIndex:-1]; }
- (void)editClassAtIndex:(NSInteger)index {
    NSMutableArray *classes = [GSStore shared].data[@"classes"];
    NSDictionary *c = index >= 0 && index < (NSInteger)classes.count ? classes[index] : nil;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:c ? @"编辑班次" : @"新增班次" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"班次名称"; tf.text = c[@"name"] ?: @"新班次"; }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSString *name = a.textFields[0].text.length ? a.textFields[0].text : @"新班次";
        NSArray *colors = @[@"#FCB819", @"#33A0FF", @"#FF9900", @"#224799", @"#067647", @"#6941C6"];
        NSMutableDictionary *nc = [@{
            @"id": c[@"id"] ?: [NSUUID UUID].UUIDString, @"name": name,
            @"color": c[@"color"] ?: colors[index >= 0 ? index % colors.count : classes.count % colors.count]
        } mutableCopy];
        if (index >= 0) classes[index] = nc; else [classes addObject:nc];
        if (index < 0) {
            NSMutableDictionary *cd = [GSStore shared].settings[@"classDefaults"];
            cd[nc[@"id"]] = [@{@"zb":@8, @"jb":@2, @"zm":@10, @"jj":@10, @"rjgz":@0} mutableCopy];
        }
        [[GSStore shared] save]; [self reload]; GSToast(@"班次已保存");
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)periodDateChanged:(UIDatePicker *)p {
    if (p.tag == 401) self.periodStart = p.date; else self.periodEnd = p.date;
}
- (void)addPeriod {
    if (!self.periodStart || !self.periodEnd || [self.periodStart compare:self.periodEnd] == NSOrderedDescending) {
        GSToast(@"起止日期不对"); return;
    }
    NSMutableDictionary *s = [GSStore shared].settings;
    NSMutableArray *periods = s[@"customPeriods"];
    if (!periods) { periods = [NSMutableArray array]; s[@"customPeriods"] = periods; }
    [periods addObject:@{@"start":GSKeyFromDate(self.periodStart), @"end":GSKeyFromDate(self.periodEnd)}];
    [[GSStore shared] save]; [self reload]; GSToast(@"周期已添加");
}
- (void)deletePeriod:(UIButton *)b {
    NSMutableDictionary *s = [GSStore shared].settings;
    NSMutableArray *periods = s[@"customPeriods"];
    if (b.tag >= 0 && b.tag < (NSInteger)periods.count) {
        [periods removeObjectAtIndex:b.tag];
        [[GSStore shared] save]; [self reload];
    }
}
@end
