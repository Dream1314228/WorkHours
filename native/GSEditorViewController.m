#import "GSEditorViewController.h"
#import "GSComponents.h"
#import "GSStore.h"

@interface GSEditorViewController () <UITextViewDelegate>
@property (nonatomic, copy) NSString *date;
@property (nonatomic, strong) NSMutableDictionary *draft;
@property (nonatomic, assign) BOOL hadRecord;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UILabel *totalLabel;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight;
@property (nonatomic, strong) NSArray *typeKeys;
@property (nonatomic, strong) NSArray *typeNames;
@end
@implementation GSEditorViewController
- (instancetype)initWithDate:(NSString *)date {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _date = [date copy]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
    self.typeKeys = @[@"zb", @"zm", @"jj", @"xiu"];
    self.typeNames = @[@"正班", @"周末", @"节假", @"休假"];
    NSDictionary *base = [[GSStore shared] recordForDate:self.date];
    self.hadRecord = base != nil;
    self.draft = base ? [base mutableCopy] : [NSMutableDictionary dictionary];
    id baseWork = self.draft[@"work"];
    if (![baseWork isKindOfClass:[NSDictionary class]]) self.draft[@"work"] = [@{@"zb":@0, @"jb":@0, @"zm":@0, @"jj":@0} mutableCopy];
    else {
        NSMutableDictionary *w = [baseWork mutableCopy];
        for (NSString *k in @[@"zb", @"jb", @"zm", @"jj"]) if (![w[k] isKindOfClass:[NSNumber class]]) w[k] = @0;
        self.draft[@"work"] = w;
    }
    id baseBT = self.draft[@"bt"];
    if ([baseBT isKindOfClass:[NSArray class]]) {
        NSMutableArray *clean = [NSMutableArray array];
        for (id b in baseBT) {
            if (![b isKindOfClass:[NSDictionary class]]) continue;
            NSMutableDictionary *bb = [b mutableCopy];
            if (![bb[@"money"] isKindOfClass:[NSNumber class]]) bb[@"money"] = @0;
            if (![bb[@"name"] isKindOfClass:[NSString class]]) bb[@"name"] = @"";
            [clean addObject:bb];
        }
        self.draft[@"bt"] = clean;
    }
    else self.draft[@"bt"] = [NSMutableArray array];
    id baseLeave = self.draft[@"leave"];
    if (baseLeave && ![baseLeave isKindOfClass:[NSDictionary class]]) [self.draft removeObjectForKey:@"leave"];
    else if ([baseLeave isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *lv = [baseLeave mutableCopy];
        if (![lv[@"hour"] isKindOfClass:[NSNumber class]]) lv[@"hour"] = @0;
        if (![lv[@"multiple"] isKindOfClass:[NSNumber class]]) lv[@"multiple"] = @0;
        if (![lv[@"type"] isKindOfClass:[NSString class]]) lv[@"type"] = @"xiu";
        self.draft[@"leave"] = lv;
    }
    id baseNote = self.draft[@"note"];
    if (![baseNote isKindOfClass:[NSString class]]) self.draft[@"note"] = @"";
    if (![self.draft[@"classId"] isKindOfClass:[NSString class]]) self.draft[@"classId"] = [GSStore shared].settings[@"currentClass"] ?: @"1";
    if (!self.hadRecord) {
        NSString *plan = [[GSStore shared] planForDate:self.date];
        if (plan.length && [[GSStore shared] classWithId:plan]) self.draft[@"classId"] = plan;
        if (![self.draft[@"type"] isKindOfClass:[NSString class]]) self.draft[@"type"] = GSDayKind(self.date);
    }
    if (![self.draft[@"projectId"] isKindOfClass:[NSString class]]) self.draft[@"projectId"] = [GSStore shared].settings[@"projectId"] ?: @"default";
    if (![self.draft[@"note"] isKindOfClass:[NSString class]]) self.draft[@"note"] = @"";
    if (![self.draft[@"type"] isKindOfClass:[NSString class]]) self.draft[@"type"] = [self inferType];
    if (![self.draft[@"settle"] isKindOfClass:[NSNumber class]]) self.draft[@"settle"] = @0;
    if (![self.draft[@"classId"] isKindOfClass:[NSString class]]) self.draft[@"classId"] = @"1";
    if (![self.draft[@"projectId"] isKindOfClass:[NSString class]]) self.draft[@"projectId"] = @"default";
    if (!self.hadRecord) [self applyDefault];
    else [[GSStore shared] ensureAutoAllowance:self.draft];

    GSGradientView *header = [[GSGradientView alloc] init];
    header.colors = @[GSThemeColor(), GSThemeDarkColor()];
    self.header = header;
    GSAddHeaderOrbs(header);
    GSApplyHeaderCorners(header);
    self.header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.header];
    self.titleLabel = GSLabel([NSString stringWithFormat:@"%ld月%ld日 · %@", (long)[[NSCalendar currentCalendar] component:NSCalendarUnitMonth fromDate:GSDateFromKey(self.date)], (long)[[NSCalendar currentCalendar] component:NSCalendarUnitDay fromDate:GSDateFromKey(self.date)], GSWeekdayName(self.date)], GSFont(17, UIFontWeightBold), UIColor.whiteColor);
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.header addSubview:self.titleLabel];
    UIButton *close = GSIconButton(@"xmark", UIColor.whiteColor, 16);
    close.backgroundColor = [UIColor colorWithWhite:0 alpha:.12]; close.layer.cornerRadius = 15;
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.backgroundColor = UIColor.clearColor;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scroll];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 10;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];

    self.bottomBar = [[UIView alloc] init];
    self.bottomBar.backgroundColor = GSColorHex(@"#FFFFFF");
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomBar];
    self.totalLabel = GSLabel(@"", GSFont(20, UIFontWeightBold), GSColorHex(@"#B45309"));
    self.totalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomBar addSubview:self.totalLabel];
    UILabel *tl = GSLabel(@"当天合计", GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    tl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomBar addSubview:tl];
    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"保存" forState:UIControlStateNormal];
    save.titleLabel.font = GSFont(16, UIFontWeightBold);
    [save setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    save.backgroundColor = GSThemeColor();
    save.layer.cornerRadius = 16; save.translatesAutoresizingMaskIntoConstraints = NO;
    [save addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:save];
    if (self.hadRecord) {
        UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
        [del setTitle:@"删除" forState:UIControlStateNormal];
        del.titleLabel.font = GSFont(14, UIFontWeightSemibold);
        [del setTitleColor:GSColorHex(@"#B42318") forState:UIControlStateNormal];
        del.backgroundColor = UIColor.whiteColor; del.layer.cornerRadius = 16;
        del.layer.borderWidth = 1; del.layer.borderColor = GSColorHex(@"#FFE0DF").CGColor;
        del.translatesAutoresizingMaskIntoConstraints = NO;
        [del addTarget:self action:@selector(deleteRecord) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomBar addSubview:del];
        [NSLayoutConstraint activateConstraints:@[
            [del.trailingAnchor constraintEqualToAnchor:save.leadingAnchor constant:-10],
            [del.centerYAnchor constraintEqualToAnchor:save.centerYAnchor],
            [del.widthAnchor constraintEqualToConstant:82], [del.heightAnchor constraintEqualToConstant:48]
        ]];
    }

    self.headerHeight = [self.header.heightAnchor constraintEqualToConstant:80];
    [NSLayoutConstraint activateConstraints:@[
        [self.header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.headerHeight,
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.header.leadingAnchor constant:20],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.header.bottomAnchor constant:-12],
        [close.trailingAnchor constraintEqualToAnchor:self.header.trailingAnchor constant:-20],
        [close.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:30], [close.heightAnchor constraintEqualToConstant:30],
        [self.scroll.topAnchor constraintEqualToAnchor:self.header.bottomAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.bottomBar.topAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:10],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:18],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-20],
        [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomBar.heightAnchor constraintEqualToConstant:88],
        [tl.leadingAnchor constraintEqualToAnchor:self.bottomBar.leadingAnchor constant:20],
        [tl.topAnchor constraintEqualToAnchor:self.bottomBar.topAnchor constant:12],
        [self.totalLabel.leadingAnchor constraintEqualToAnchor:tl.leadingAnchor],
        [self.totalLabel.topAnchor constraintEqualToAnchor:tl.bottomAnchor constant:2],
        [save.trailingAnchor constraintEqualToAnchor:self.bottomBar.trailingAnchor constant:-20],
        [save.centerYAnchor constraintEqualToAnchor:self.bottomBar.centerYAnchor constant:-6],
        [save.widthAnchor constraintEqualToConstant:130], [save.heightAnchor constraintEqualToConstant:48]
    ]];
    [self reloadContent];
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    self.headerHeight.constant = self.view.safeAreaInsets.top + 52;
    self.header.startY = self.view.safeAreaInsets.top / MAX(1, self.headerHeight.constant);
    self.bottomBar.frame = self.bottomBar.frame;
    for (NSLayoutConstraint *c in self.bottomBar.constraints) {
        if (c.firstAttribute == NSLayoutAttributeHeight) c.constant = 64 + self.view.safeAreaInsets.bottom;
    }
}
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (NSString *)inferType {
    NSDictionary *w = self.draft[@"work"] ?: @{};
    if ([self.draft[@"leave"] isKindOfClass:[NSDictionary class]]) return @"xiu";
    if ([w[@"zm"] doubleValue] > 0) return @"zm";
    if ([w[@"jj"] doubleValue] > 0) return @"jj";
    return @"zb";
}
- (void)applyDefault {
    NSMutableArray *bt = self.draft[@"bt"];
    if ([bt isKindOfClass:[NSArray class]]) {
        NSMutableArray *keep = [NSMutableArray array];
        for (NSDictionary *b in bt) if (![b isKindOfClass:[NSDictionary class]] || ![b[@"autoAllowance"] boolValue]) [keep addObject:b];
        self.draft[@"bt"] = keep;
    }
    NSDictionary *def = [[GSStore shared] defaultWorkForClass:self.draft[@"classId"]];
    self.draft[@"work"] = [@{@"zb":@0, @"jb":@0, @"zm":@0, @"jj":@0} mutableCopy];
    [self.draft removeObjectForKey:@"leave"];
    self.draft[@"settle"] = @0;
    NSString *type = self.draft[@"type"];
    if ([type isEqual:@"zb"]) {
        self.draft[@"work"][@"zb"] = @([def[@"zb"] doubleValue]);
        self.draft[@"work"][@"jb"] = @([def[@"jb"] doubleValue]);
    } else if ([type isEqual:@"zm"]) {
        self.draft[@"work"][@"zm"] = @([def[@"zm"] doubleValue]);
    } else if ([type isEqual:@"jj"]) {
        self.draft[@"work"][@"jj"] = @([def[@"jj"] doubleValue]);
    } else if ([type isEqual:@"xiu"]) {
        self.draft[@"leave"] = [@{@"type":@"xiu", @"hour":@8, @"rule":@"hour", @"multiple":@0} mutableCopy];
    }
    if ([def[@"rjgz"] doubleValue] > 0) self.draft[@"settle"] = def[@"rjgz"];
    [[GSStore shared] ensureAutoAllowance:self.draft];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (UIView *)cardWithTitle:(NSString *)title content:(UIView *)content {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.whiteColor;
    card.layer.cornerRadius = 20;
    UIStackView *v = [[UIStackView alloc] init];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 10; v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    UILabel *t = GSLabel(title, GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
    [v addArrangedSubview:t];
    if (content) [v addArrangedSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    return card;
}
- (UIView *)spacer { return GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor); }
- (void)reloadContent {
    for (UIView *v in self.stack.arrangedSubviews) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
    NSArray *classes = [[GSStore shared] classes];
    NSString *type = self.draft[@"type"] ?: @"zb";

    UISegmentedControl *typeSeg = [[UISegmentedControl alloc] initWithItems:self.typeNames];
    typeSeg.selectedSegmentIndex = [self.typeKeys indexOfObject:type] == NSNotFound ? 0 : [self.typeKeys indexOfObject:type];
    typeSeg.selectedSegmentTintColor = GSThemeColor();
    typeSeg.backgroundColor = GSColorHex(@"#EEF3FA");
    [typeSeg setTitleTextAttributes:@{NSForegroundColorAttributeName:GSColorHex(@"#667085"), NSFontAttributeName:GSFont(12, UIFontWeightSemibold)} forState:UIControlStateNormal];
    [typeSeg setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor, NSFontAttributeName:GSFont(12, UIFontWeightSemibold)} forState:UIControlStateSelected];
    [typeSeg addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.stack addArrangedSubview:[self cardWithTitle:@"当天类型" content:typeSeg]];

    NSMutableArray *chips = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)classes.count; i++) {
        NSDictionary *c = classes[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:c[@"name"] forState:UIControlStateNormal];
        b.titleLabel.font = GSFont(12, UIFontWeightSemibold);
        b.tag = i;
        b.layer.cornerRadius = 10; b.layer.borderWidth = 1.5;
        BOOL on = [c[@"id"] isEqual:self.draft[@"classId"]];
        b.backgroundColor = on ? GSThemeSoftColor() : GSColorHex(@"#F2F5FA");
        b.layer.borderColor = (on ? GSThemeColor() : UIColor.clearColor).CGColor;
        [b setTitleColor:(on ? GSThemeColor() : GSColorHex(@"#667085")) forState:UIControlStateNormal];
        [b.heightAnchor constraintEqualToConstant:36].active = YES;
        [b addTarget:self action:@selector(classTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chips addObject:b];
    }
    UIStackView *classStack = GSStack(chips, UILayoutConstraintAxisHorizontal, 6);
    classStack.distribution = UIStackViewDistributionFillEqually;
    [self.stack addArrangedSubview:[self cardWithTitle:@"班次" content:classStack]];

    UIButton *projectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [projectBtn setTitle:[[GSStore shared] projectWithId:self.draft[@"projectId"]][@"name"] forState:UIControlStateNormal];
    [projectBtn setTitleColor:GSColorHex(@"#101828") forState:UIControlStateNormal];
    projectBtn.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    projectBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    projectBtn.backgroundColor = GSColorHex(@"#F5F7FA");
    projectBtn.layer.cornerRadius = 10;
    projectBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    [projectBtn.heightAnchor constraintEqualToConstant:40].active = YES;
    projectBtn.showsMenuAsPrimaryAction = YES;
    NSMutableArray *actions = [NSMutableArray array];
    for (NSDictionary *p in [[GSStore shared] projects]) {
        UIAction *act = [UIAction actionWithTitle:p[@"name"] image:nil identifier:nil handler:^(__kindof UIAction *a) {
            self.draft[@"projectId"] = p[@"id"];
            [self reloadContent];
        }];
        [actions addObject:act];
    }
    projectBtn.menu = [UIMenu menuWithTitle:@"" children:actions];
    [self.stack addArrangedSubview:[self cardWithTitle:@"项目" content:projectBtn]];

    NSMutableArray *workRows = [NSMutableArray array];
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj"];
    NSArray *names = @[@"正班", @"加班", @"周末", @"节假"];
    for (NSInteger i = 0; i < 4; i++) {
        double h = [self.draft[@"work"][keys[i]] doubleValue];
        UILabel *n = GSLabel(names[i], GSFont(14, UIFontWeightSemibold), GSColorHex(@"#101828"));
        [n.widthAnchor constraintEqualToConstant:42].active = YES;
        UILabel *rate = GSLabel([NSString stringWithFormat:@"¥%@/h", GSNum([[GSStore shared] rateForProject:self.draft[@"projectId"] type:keys[i]])], GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        UIView *sp = [self spacer];
        UILabel *pay = GSLabel(GSMoney(h * [[GSStore shared] rateForProject:self.draft[@"projectId"] type:keys[i]]), GSFont(14, UIFontWeightBold), i == 0 ? GSColorHex(@"#101828") : GSColorHex(@"#B45309"));
        pay.textAlignment = NSTextAlignmentRight; pay.tag = 300 + i;
        [pay.widthAnchor constraintEqualToConstant:64].active = YES;
        UITextField *hoursField = [[UITextField alloc] init];
        hoursField.text = GSNum(h);
        hoursField.keyboardType = UIKeyboardTypeDecimalPad;
        hoursField.font = GSFont(13, UIFontWeightBold);
        hoursField.textColor = GSThemeColor();
        hoursField.textAlignment = NSTextAlignmentRight;
        hoursField.backgroundColor = GSColorHex(@"#F5F7FA");
        hoursField.layer.cornerRadius = 8;
        hoursField.tag = 400 + i;
        [hoursField addTarget:self action:@selector(workHoursChanged:) forControlEvents:UIControlEventEditingChanged];
        [hoursField.widthAnchor constraintEqualToConstant:46].active = YES;
        [hoursField.heightAnchor constraintEqualToConstant:32].active = YES;
        UILabel *unit = GSLabel(@"H", GSFont(10, UIFontWeightRegular), GSColorHex(@"#667085"));
        [unit.widthAnchor constraintEqualToConstant:10].active = YES;
        UIStackView *row = GSStack(@[n, rate, sp, hoursField, unit, pay], UILayoutConstraintAxisHorizontal, 5);
        row.alignment = UIStackViewAlignmentCenter;
        [workRows addObject:row];
    }
    UIStackView *workStack = GSStack(workRows, UILayoutConstraintAxisVertical, 10);
    [self.stack addArrangedSubview:[self cardWithTitle:@"工时 · 按项目时薪算" content:workStack]];

    UITextField *settle = [[UITextField alloc] init];
    settle.keyboardType = UIKeyboardTypeDecimalPad;
    settle.font = GSFont(14, UIFontWeightRegular);
    settle.textColor = GSColorHex(@"#101828"); settle.tintColor = GSThemeColor();
    settle.attributedPlaceholder = GSPlaceholder(@"0（填了就不按工时算）", settle.font);
    settle.backgroundColor = GSColorHex(@"#F5F7FA"); settle.layer.cornerRadius = 12;
    settle.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)]; settle.leftViewMode = UITextFieldViewModeAlways;
    settle.text = [self.draft[@"settle"] doubleValue] > 0 ? GSNum([self.draft[@"settle"] doubleValue]) : @"";
    [settle.heightAnchor constraintEqualToConstant:40].active = YES;
    [settle addTarget:self action:@selector(settleChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.stack addArrangedSubview:[self cardWithTitle:@"日结 · 填了就不按工时算" content:settle]];

    [self addLeaveSection];
    [self addBTSection];
    [self addNoteSection];
    [self updateTotal];
    GSAnimateStack(self.stack);
}
- (void)addLeaveSection {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.whiteColor; card.layer.cornerRadius = 20;
    UIStackView *v = [[UIStackView alloc] init];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 8; v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    UILabel *t = GSLabel(@"休假", GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
    UILabel *sub = GSLabel(@"按倍数算补贴/扣款", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UIView *sp = [self spacer];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = GSThemeColor();
    sw.on = [self.draft[@"leave"] isKindOfClass:[NSDictionary class]];
    [sw addTarget:self action:@selector(leaveToggle:) forControlEvents:UIControlEventValueChanged];
    UIStackView *top = GSStack(@[t, sub, sp, sw], UILayoutConstraintAxisHorizontal, 8);
    top.alignment = UIStackViewAlignmentCenter;
    [v addArrangedSubview:top];
    UILabel *annualBalance = GSLabel(@"", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    annualBalance.tag = 904; annualBalance.numberOfLines = 0;
    [v addArrangedSubview:annualBalance];
    [self updateAnnualLeaveBalance];
    if ([self.draft[@"leave"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *leave = self.draft[@"leave"];
        UISegmentedControl *types = [[UISegmentedControl alloc] initWithItems:@[@"病假", @"事假", @"调休", @"薪假"]];
        NSArray *tk = @[@"bing", @"shi", @"tiao", @"xiu"];
        types.selectedSegmentIndex = [tk indexOfObject:leave[@"type"]] == NSNotFound ? 3 : [tk indexOfObject:leave[@"type"]];
        types.selectedSegmentTintColor = GSThemeColor();
        types.tag = 903;
        [types addTarget:self action:@selector(leaveTypeChanged:) forControlEvents:UIControlEventValueChanged];
        [v addArrangedSubview:types];
        UILabel *hl = GSLabel(@"时长", GSFont(13, UIFontWeightMedium), GSColorHex(@"#667085"));
        UILabel *hv = GSLabel([NSString stringWithFormat:@"%@H", GSNum([leave[@"hour"] doubleValue])], GSFont(13, UIFontWeightBold), GSThemeColor());
        hv.tag = 902;
        UIView *sp2 = [self spacer];
        UIStepper *st = [[UIStepper alloc] init];
        st.minimumValue = 0; st.maximumValue = 24; st.stepValue = 1; st.value = [leave[@"hour"] doubleValue]; st.tag = 900;
        [st addTarget:self action:@selector(leaveHourChanged:) forControlEvents:UIControlEventValueChanged];
        UIStackView *hr = GSStack(@[hl, sp2, hv, st], UILayoutConstraintAxisHorizontal, 8);
        hr.alignment = UIStackViewAlignmentCenter;
        [v addArrangedSubview:hr];
        UILabel *ml = GSLabel(@"倍数", GSFont(13, UIFontWeightMedium), GSColorHex(@"#667085"));
        UISegmentedControl *mults = [[UISegmentedControl alloc] initWithItems:@[@"0", @"0.5", @"1", @"1.5", @"2", @"3"]];
        NSArray *mv = @[@0, @0.5, @1, @1.5, @2, @3];
        NSInteger mi = [mv indexOfObject:@([leave[@"multiple"] doubleValue])];
        mults.selectedSegmentIndex = mi == NSNotFound ? 0 : mi;
        mults.selectedSegmentTintColor = GSThemeColor(); mults.tag = 901;
        [mults addTarget:self action:@selector(leaveMultChanged:) forControlEvents:UIControlEventValueChanged];
        UIView *mrow = [[UIView alloc] init];
        [mrow addSubview:ml]; [mrow addSubview:mults];
        ml.translatesAutoresizingMaskIntoConstraints = NO; mults.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [ml.leadingAnchor constraintEqualToAnchor:mrow.leadingAnchor],
            [ml.centerYAnchor constraintEqualToAnchor:mrow.centerYAnchor],
            [mults.leadingAnchor constraintEqualToAnchor:ml.trailingAnchor constant:8],
            [mults.trailingAnchor constraintEqualToAnchor:mrow.trailingAnchor],
            [mults.topAnchor constraintEqualToAnchor:mrow.topAnchor], [mults.bottomAnchor constraintEqualToAnchor:mrow.bottomAnchor],
            [mrow.heightAnchor constraintEqualToConstant:32]
        ]];
        [v addArrangedSubview:mrow];
    }
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
    ]];
    [self.stack addArrangedSubview:card];
}
- (void)addBTSection {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.whiteColor; card.layer.cornerRadius = 20;
    UIStackView *v = [[UIStackView alloc] init];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 8; v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    UILabel *t = GSLabel(@"补扣", GSFont(15, UIFontWeightBold), GSColorHex(@"#101828"));
    [v addArrangedSubview:t];
    NSArray *bt = self.draft[@"bt"] ?: @[];
    for (NSInteger i = 0; i < (NSInteger)bt.count; i++) {
        NSDictionary *b = bt[i];
        UITextField *name = [[UITextField alloc] init];
        name.text = b[@"name"] ?: @"";
        name.font = GSFont(12, UIFontWeightRegular);
        name.textColor = GSColorHex(@"#101828"); name.tintColor = GSThemeColor();
        name.backgroundColor = GSColorHex(@"#F5F7FA"); name.layer.cornerRadius = 10;
        name.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 1)]; name.leftViewMode = UITextFieldViewModeAlways;
        name.tag = 1000 + i; name.attributedPlaceholder = GSPlaceholder(@"名称", name.font);
        [name addTarget:self action:@selector(btFieldChanged:) forControlEvents:UIControlEventEditingChanged];
        UITextField *amount = [[UITextField alloc] init];
        double m = [b[@"money"] doubleValue];
        amount.text = fabs(m) > 0 ? GSNum(fabs(m)) : @"";
        amount.keyboardType = UIKeyboardTypeDecimalPad;
        amount.font = GSFont(12, UIFontWeightSemibold); amount.textAlignment = NSTextAlignmentRight;
        amount.textColor = GSColorHex(@"#101828"); amount.tintColor = GSThemeColor();
        amount.attributedPlaceholder = GSPlaceholder(@"金额", amount.font);
        amount.backgroundColor = GSColorHex(@"#F5F7FA"); amount.layer.cornerRadius = 10;
        amount.tag = 2000 + i;
        [amount addTarget:self action:@selector(btFieldChanged:) forControlEvents:UIControlEventEditingChanged];
        UIButton *del = GSIconButton(@"trash", GSColorHex(@"#5D6B82"), 14);
        del.tag = i; [del addTarget:self action:@selector(deleteBT:) forControlEvents:UIControlEventTouchUpInside];
        UIStackView *row = GSStack(@[name, amount, del], UILayoutConstraintAxisHorizontal, 6);
        [name.widthAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
        [amount.widthAnchor constraintEqualToConstant:78].active = YES;
        [del.widthAnchor constraintEqualToConstant:28].active = YES;
        [name.heightAnchor constraintEqualToConstant:34].active = YES;
        [amount.heightAnchor constraintEqualToConstant:34].active = YES;
        [v addArrangedSubview:row];
    }
    if (bt.count == 0) {
        UILabel *empty = GSLabel(@"还没有补扣", GSFont(11, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
        [v addArrangedSubview:empty];
    }
    UIButton *addB = [UIButton buttonWithType:UIButtonTypeSystem];
    [addB setTitle:@"+ 补贴" forState:UIControlStateNormal]; addB.titleLabel.font = GSFont(12, UIFontWeightSemibold); addB.tag = 1;
    [addB addTarget:self action:@selector(addBT:) forControlEvents:UIControlEventTouchUpInside];
    UIButton *addD = [UIButton buttonWithType:UIButtonTypeSystem];
    [addD setTitle:@"+ 扣款" forState:UIControlStateNormal]; addD.titleLabel.font = GSFont(12, UIFontWeightSemibold); addD.tag = -1;
    [addD setTitleColor:GSColorHex(@"#B42318") forState:UIControlStateNormal];
    [addD addTarget:self action:@selector(addBT:) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *addRow = GSStack(@[addB, addD, [self spacer]], UILayoutConstraintAxisHorizontal, 12);
    [v addArrangedSubview:addRow];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
    ]];
    [self.stack addArrangedSubview:card];
}
- (void)addNoteSection {
    UITextView *tv = [[UITextView alloc] init];
    tv.text = self.draft[@"note"] ?: @"";
    tv.font = GSFont(13, UIFontWeightRegular);
    tv.textColor = GSColorHex(@"#101828");
    tv.backgroundColor = GSColorHex(@"#F5F7FA"); tv.layer.cornerRadius = 10;
    tv.delegate = self;
    [tv.heightAnchor constraintEqualToConstant:76].active = YES;
    [self.stack addArrangedSubview:[self cardWithTitle:@"备注" content:tv]];
}
- (void)updateTotal {
    self.totalLabel.text = GSMoney([[GSStore shared] dayPay:self.draft]);
}
- (void)typeChanged:(UISegmentedControl *)s {
    self.draft[@"type"] = self.typeKeys[s.selectedSegmentIndex];
    [self applyDefault];
    [self reloadContent];
}
- (void)classTapped:(UIButton *)b {
    NSArray *classes = [[GSStore shared] classes];
    if (b.tag < 0 || b.tag >= (NSInteger)classes.count) return;
    self.draft[@"classId"] = classes[b.tag][@"id"];
    [self applyDefault];
    [self reloadContent];
}
- (void)workHoursChanged:(UITextField *)f {
    NSInteger i = f.tag - 400;
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj"];
    if (i < 0 || i >= 4) return;
    double h = MAX(0, MIN(24, f.text.doubleValue));
    if (f.text.doubleValue > 24) f.text = @"24";
    self.draft[@"work"][keys[i]] = @(h);
    UILabel *pay = (UILabel *)[self.stack viewWithTag:300 + i];
    if (pay) pay.text = GSMoney(h * [[GSStore shared] rateForProject:self.draft[@"projectId"] type:keys[i]]);
    [self updateTotal];
}
- (void)workStepper:(UIStepper *)st {
    NSArray *keys = @[@"zb", @"jb", @"zm", @"jj"];
    NSString *key = keys[st.tag];
    self.draft[@"work"][key] = @(st.value);
    UILabel *pay = (UILabel *)[self.stack viewWithTag:300 + st.tag];
    if (pay) pay.text = GSMoney(st.value * [[GSStore shared] rateForProject:self.draft[@"projectId"] type:key]);
    [self updateTotal];
}
- (void)settleChanged:(UITextField *)f {
    self.draft[@"settle"] = @(f.text.doubleValue);
    [self updateTotal];
}
- (void)updateAnnualLeaveBalance {
    UILabel *l = (UILabel *)[self.stack viewWithTag:904];
    if (!l) return;
    NSDate *d = GSDateFromKey(self.date);
    NSInteger year = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] component:NSCalendarUnitYear fromDate:d];
    double total = [[GSStore shared] annualLeaveTotalDays];
    double used = [[GSStore shared] annualLeaveUsedDaysForYear:year];
    double remain = [[GSStore shared] annualLeaveRemainingDaysForYear:year];
    if (total <= 0) {
        l.text = [NSString stringWithFormat:@"%ld 年年假未设置 · 去「记录设置」调整", (long)year];
    } else {
        l.text = [NSString stringWithFormat:@"%ld 年年假：总额 %@ 天 · 已用 %@ 天 · 剩余 %@ 天", (long)year, GSNum(total), GSNum(used), GSNum(remain)];
    }
}
- (void)leaveToggle:(UISwitch *)sw {
    if (sw.on) self.draft[@"leave"] = [@{@"type":@"xiu", @"hour":@8, @"rule":@"hour", @"multiple":@0} mutableCopy];
    else [self.draft removeObjectForKey:@"leave"];
    [self reloadContent];
}
- (void)leaveTypeChanged:(UISegmentedControl *)s {
    NSArray *tk = @[@"bing", @"shi", @"tiao", @"xiu"];
    NSMutableDictionary *leave = self.draft[@"leave"];
    if (![leave isKindOfClass:[NSMutableDictionary class]]) return;
    leave[@"type"] = tk[s.selectedSegmentIndex];
    [self updateTotal]; [self updateAnnualLeaveBalance];
}
- (void)leaveHourChanged:(UIStepper *)st {
    NSMutableDictionary *leave = self.draft[@"leave"];
    if (![leave isKindOfClass:[NSMutableDictionary class]]) return;
    leave[@"hour"] = @(st.value);
    UILabel *hv = (UILabel *)[self.stack viewWithTag:902];
    if (hv) hv.text = [NSString stringWithFormat:@"%@H", GSNum(st.value)];
    [self updateTotal]; [self updateAnnualLeaveBalance];
}
- (void)leaveMultChanged:(UISegmentedControl *)s {
    NSArray *mv = @[@0, @0.5, @1, @1.5, @2, @3];
    NSMutableDictionary *leave = self.draft[@"leave"];
    if (![leave isKindOfClass:[NSMutableDictionary class]]) return;
    leave[@"multiple"] = mv[s.selectedSegmentIndex];
    [self updateTotal]; [self updateAnnualLeaveBalance];
}
- (void)addBT:(UIButton *)b {
    NSMutableArray *bt = self.draft[@"bt"];
    [bt addObject:[@{@"name":b.tag > 0 ? @"补贴" : @"扣款", @"money":@0, @"sign":@(b.tag)} mutableCopy]];
    [self reloadContent];
}
- (void)deleteBT:(UIButton *)b {
    NSMutableArray *bt = self.draft[@"bt"];
    if (b.tag >= 0 && b.tag < (NSInteger)bt.count) { [bt removeObjectAtIndex:b.tag]; [self reloadContent]; }
}
- (void)btFieldChanged:(UITextField *)f {
    NSInteger i = f.tag % 1000;
    BOOL isMoney = f.tag >= 2000;
    NSMutableArray *bt = self.draft[@"bt"];
    if (i < 0 || i >= (NSInteger)bt.count) return;
    NSMutableDictionary *b = bt[i];
    if (isMoney) {
        double sign = [b[@"sign"] doubleValue];
        if (sign == 0) sign = [b[@"money"] doubleValue] < 0 ? -1 : 1;
        b[@"money"] = @(sign * fabs(f.text.doubleValue));
    } else {
        b[@"name"] = f.text;
    }
    [self updateTotal];
}
- (void)textViewDidChange:(UITextView *)textView {
    self.draft[@"note"] = textView.text ?: @"";
}
- (void)save {
    NSDictionary *work = self.draft[@"work"] ?: @{};
    for (NSString *k in @[@"zb", @"jb", @"zm", @"jj"]) {
        double v = [work[k] doubleValue];
        self.draft[@"work"][k] = @(MIN(24, MAX(0, v)));
    }
    self.draft[@"settle"] = @(MAX(0, [self.draft[@"settle"] doubleValue]));
    [[GSStore shared] ensureAutoAllowance:self.draft];
    NSMutableArray *bt = [NSMutableArray array];
    for (NSDictionary *b in self.draft[@"bt"] ?: @[]) {
        NSString *n = [b[@"name"] description] ?: @"";
        double m = [b[@"money"] doubleValue];
        if (n.length || fabs(m) > 0.001) [bt addObject:b];
    }
    self.draft[@"bt"] = bt;
    NSDictionary *leave = self.draft[@"leave"];
    if ([leave isKindOfClass:[NSDictionary class]]) {
        if ([leave[@"hour"] doubleValue] <= 0) [self.draft removeObjectForKey:@"leave"];
    }
    NSString *note = [self.draft[@"note"] description] ?: @"";
    if ([note isEqual:@"(null)"]) note = @"";
    self.draft[@"note"] = note;
    BOOL has = NO;
    for (NSString *k in @[@"zb", @"jb", @"zm", @"jj"]) if ([self.draft[@"work"][k] doubleValue] > 0) has = YES;
    if ([self.draft[@"leave"] isKindOfClass:[NSDictionary class]]) has = YES;
    if (bt.count > 0) has = YES;
    if ([self.draft[@"settle"] doubleValue] > 0) has = YES;
    if (note.length > 0) has = YES;
    if (has) [[GSStore shared] setRecord:self.draft forDate:self.date];
    else [[GSStore shared] removeRecordForDate:self.date];
    if (self.onSaved) self.onSaved();
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)deleteRecord {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"删除记录" message:@"删除这一天的全部工时？" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [[GSStore shared] removeRecordForDate:self.date];
        if (self.onSaved) self.onSaved();
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
