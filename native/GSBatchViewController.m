#import "GSBatchViewController.h"
#import "GSComponents.h"
#import "GSStore.h"

@interface GSBatchViewController ()
@property (nonatomic, copy) NSString *initialKey;
@property (nonatomic, assign) NSInteger year, month;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedKeys;
@property (nonatomic, strong) UILabel *monthLabel, *countLabel;
@property (nonatomic, strong) UIStackView *calendarStack, *stack;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UITextField *hoursField, *otField, *bonusField;
@property (nonatomic, strong) UISegmentedControl *classSeg;
@property (nonatomic, strong) UISwitch *blankSwitch, *weekendSwitch;
@property (nonatomic, strong) NSArray *classes;
- (UITextField *)numberField:(NSString *)text color:(UIColor *)color size:(CGFloat)size;
- (NSString *)classIdForNight:(BOOL)night;
- (NSMutableArray *)bonusArrayForRecord:(NSMutableDictionary *)rec;
- (void)putBonus:(double)bonus inRecord:(NSMutableDictionary *)rec;
- (void)applyLeave;
- (void)confirmClear;
- (void)doClear;
@end

@implementation GSBatchViewController
- (instancetype)initWithStartDate:(NSString *)start endDate:(NSString *)end {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _initialKey = [start copy]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"批量设置工时";
    self.view.backgroundColor = GSColorHex(@"#F2F5FA");
    self.navigationController.navigationBar.tintColor = GSThemeColor();
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"应用" style:UIBarButtonItemStyleDone target:self action:@selector(apply)];

    NSDate *d = GSDateFromKey(self.initialKey ?: GSTodayKey());
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    self.year = [cal component:NSCalendarUnitYear fromDate:d];
    self.month = [cal component:NSCalendarUnitMonth fromDate:d];
    self.selectedKeys = [NSMutableSet setWithObject:GSKeyFromDate(d)];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical;
    self.stack.spacing = 14;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:16],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-130]
    ]];

    [self buildCalendarCard];
    [self buildOptions];
}
- (void)buildCalendarCard {
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical; content.spacing = 10;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:content];

    UIButton *prev = GSIconButton(@"chevron.left", GSThemeColor(), 15);
    UIButton *next = GSIconButton(@"chevron.right", GSThemeColor(), 15);
    prev.translatesAutoresizingMaskIntoConstraints = NO; next.translatesAutoresizingMaskIntoConstraints = NO;
    [prev addTarget:self action:@selector(prevMonth) forControlEvents:UIControlEventTouchUpInside];
    [next addTarget:self action:@selector(nextMonth) forControlEvents:UIControlEventTouchUpInside];
    self.monthLabel = GSLabel(@"", GSFont(16, UIFontWeightBold), GSColorHex(@"#101828"));
    self.monthLabel.textAlignment = NSTextAlignmentCenter;
    UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *head = GSStack(@[prev, self.monthLabel, sp, next], UILayoutConstraintAxisHorizontal, 8);
    head.alignment = UIStackViewAlignmentCenter;
    [prev.widthAnchor constraintEqualToConstant:30].active = YES; [prev.heightAnchor constraintEqualToConstant:30].active = YES;
    [next.widthAnchor constraintEqualToConstant:30].active = YES; [next.heightAnchor constraintEqualToConstant:30].active = YES;

    NSInteger weekStart = [[GSStore shared].settings[@"weekStart"] integerValue] == 0 ? 0 : 1;
    NSArray *weekNames = weekStart == 0 ? @[@"日", @"一", @"二", @"三", @"四", @"五", @"六"] : @[@"一", @"二", @"三", @"四", @"五", @"六", @"日"];
    NSMutableArray *weekLabels = [NSMutableArray array];
    for (NSString *name in weekNames) {
        UILabel *l = GSLabel(name, GSFont(10, UIFontWeightMedium), GSColorHex(@"#98A2B3"));
        l.textAlignment = NSTextAlignmentCenter;
        [weekLabels addObject:l];
    }
    UIStackView *weekRow = GSStack(weekLabels, UILayoutConstraintAxisHorizontal, 2);
    weekRow.distribution = UIStackViewDistributionFillEqually;

    self.calendarStack = [[UIStackView alloc] init];
    self.calendarStack.axis = UILayoutConstraintAxisVertical; self.calendarStack.spacing = 2;

    UIButton *all = [UIButton buttonWithType:UIButtonTypeSystem];
    [all setTitle:@"全月" forState:UIControlStateNormal]; all.titleLabel.font = GSFont(11, UIFontWeightSemibold);
    [all setTitleColor:GSThemeColor() forState:UIControlStateNormal];
    [all addTarget:self action:@selector(selectWholeMonth) forControlEvents:UIControlEventTouchUpInside];
    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    [clear setTitle:@"清空" forState:UIControlStateNormal]; clear.titleLabel.font = GSFont(11, UIFontWeightSemibold);
    [clear setTitleColor:GSColorHex(@"#667085") forState:UIControlStateNormal];
    [clear addTarget:self action:@selector(clearSelection) forControlEvents:UIControlEventTouchUpInside];
    self.countLabel = GSLabel(@"", GSFont(11, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UIView *countSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *bottom = GSStack(@[all, clear, countSp, self.countLabel], UILayoutConstraintAxisHorizontal, 12);
    bottom.alignment = UIStackViewAlignmentCenter;

    [content addArrangedSubview:head];
    [content addArrangedSubview:weekRow];
    [content addArrangedSubview:self.calendarStack];
    [content addArrangedSubview:bottom];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
    ]];
    [self.stack addArrangedSubview:card];
    [self buildCalendar];
}
- (void)buildCalendar {
    self.monthLabel.text = [NSString stringWithFormat:@"%ld年%ld月", (long)self.year, (long)self.month];
    for (UIView *v in self.calendarStack.arrangedSubviews) {
        [self.calendarStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    NSInteger weekStart = [[GSStore shared].settings[@"weekStart"] integerValue] == 0 ? 0 : 1;
    NSInteger dim = GSDaysInMonth(self.year, self.month);
    NSDateComponents *c = [[NSDateComponents alloc] init]; c.year = self.year; c.month = self.month; c.day = 1;
    NSDate *first = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] dateFromComponents:c];
    NSInteger weekday = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] component:NSCalendarUnitWeekday fromDate:first];
    NSInteger offset = (weekday - 1 - weekStart + 7) % 7;
    for (NSInteger row = 0; row < 6; row++) {
        NSMutableArray *cells = [NSMutableArray array];
        for (NSInteger col = 0; col < 7; col++) {
            NSInteger index = row * 7 + col - offset + 1;
            if (index < 1 || index > dim) {
                UIView *empty = [[UIView alloc] init];
                [empty.heightAnchor constraintEqualToConstant:36].active = YES;
                [cells addObject:empty];
                continue;
            }
            NSString *key = [NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)self.year, (long)self.month, (long)index];
            BOOL selected = [self.selectedKeys containsObject:key];
            BOOL recorded = [[GSStore shared] recordForDate:key] != nil;
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.accessibilityIdentifier = key;
            b.titleLabel.font = GSFont(13, selected ? UIFontWeightBold : UIFontWeightRegular);
            [b setTitle:[NSString stringWithFormat:@"%ld", (long)index] forState:UIControlStateNormal];
            [b setTitleColor:selected ? UIColor.whiteColor : GSColorHex(@"#101828") forState:UIControlStateNormal];
            b.backgroundColor = selected ? GSThemeColor() : UIColor.clearColor;
            b.layer.cornerRadius = 18;
            [b.heightAnchor constraintEqualToConstant:36].active = YES;
            [b addTarget:self action:@selector(toggleDate:) forControlEvents:UIControlEventTouchUpInside];
            if (recorded) {
                UIView *dot = [[UIView alloc] init];
                dot.backgroundColor = selected ? UIColor.whiteColor : GSThemeColor();
                dot.layer.cornerRadius = 2;
                dot.translatesAutoresizingMaskIntoConstraints = NO;
                [b addSubview:dot];
                [NSLayoutConstraint activateConstraints:@[
                    [dot.centerXAnchor constraintEqualToAnchor:b.centerXAnchor],
                    [dot.bottomAnchor constraintEqualToAnchor:b.bottomAnchor constant:-3],
                    [dot.widthAnchor constraintEqualToConstant:4], [dot.heightAnchor constraintEqualToConstant:4]
                ]];
            }
            if ([key isEqual:GSTodayKey()] && !selected) {
                b.layer.borderWidth = 1; b.layer.borderColor = GSThemeColor().CGColor;
            }
            [cells addObject:b];
        }
        UIStackView *rowStack = GSStack(cells, UILayoutConstraintAxisHorizontal, 2);
        rowStack.distribution = UIStackViewDistributionFillEqually;
        [self.calendarStack addArrangedSubview:rowStack];
    }
    self.countLabel.text = [NSString stringWithFormat:@"已选 %ld 天", (long)self.selectedKeys.count];
}
- (void)prevMonth {
    NSDateComponents *c = GSMonthAdd(self.year, self.month, -1);
    self.year = c.year; self.month = c.month; [self buildCalendar];
}
- (void)nextMonth {
    NSDateComponents *c = GSMonthAdd(self.year, self.month, 1);
    self.year = c.year; self.month = c.month; [self buildCalendar];
}
- (void)toggleDate:(UIButton *)b {
    NSString *key = b.accessibilityIdentifier;
    if (!key.length) return;
    if ([self.selectedKeys containsObject:key]) [self.selectedKeys removeObject:key];
    else [self.selectedKeys addObject:key];
    GSHaptic(); [self buildCalendar];
}
- (void)selectWholeMonth {
    NSInteger dim = GSDaysInMonth(self.year, self.month);
    for (NSInteger d = 1; d <= dim; d++) {
        [self.selectedKeys addObject:[NSString stringWithFormat:@"%04ld-%02ld-%02ld", (long)self.year, (long)self.month, (long)d]];
    }
    [self buildCalendar];
}
- (void)clearSelection { [self.selectedKeys removeAllObjects]; [self buildCalendar]; }
- (void)buildOptions {
    self.classes = [[GSStore shared] classes];
    GSCardView *hoursCard = [[GSCardView alloc] init];
    UILabel *hoursTitle = GSLabel(@"每天工时", GSFont(13, UIFontWeightSemibold), GSColorHex(@"#344054"));
    self.hoursField = [self numberField:@"8" color:GSThemeColor() size:22];
    self.otField = [self numberField:@"0" color:GSColorHex(@"#D92D20") size:22];
    UILabel *normalL = GSLabel(@"正常工时", GSFont(10, UIFontWeightRegular), GSColorHex(@"#667085"));
    UILabel *otL = GSLabel(@"加班工时", GSFont(10, UIFontWeightRegular), GSColorHex(@"#667085"));
    normalL.textAlignment = NSTextAlignmentCenter; otL.textAlignment = NSTextAlignmentCenter;
    UIStackView *normalCol = GSStack(@[self.hoursField, normalL], UILayoutConstraintAxisVertical, 4);
    UIStackView *otCol = GSStack(@[self.otField, otL], UILayoutConstraintAxisVertical, 4);
    UIStackView *fields = GSStack(@[normalCol, otCol], UILayoutConstraintAxisHorizontal, 10);
    fields.distribution = UIStackViewDistributionFillEqually;
    UILabel *hoursHint = GSLabel(@"正常工时自动落到正班/周末/节假；加班统一记加班。识别周末和法定节假日。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#667085"));
    hoursHint.numberOfLines = 0;
    UIStackView *hv = GSStack(@[hoursTitle, fields, hoursHint], UILayoutConstraintAxisVertical, 10);
    hv.translatesAutoresizingMaskIntoConstraints = NO; [hoursCard addSubview:hv];
    [NSLayoutConstraint activateConstraints:@[
        [hv.topAnchor constraintEqualToAnchor:hoursCard.topAnchor constant:16],
        [hv.leadingAnchor constraintEqualToAnchor:hoursCard.leadingAnchor constant:16],
        [hv.trailingAnchor constraintEqualToAnchor:hoursCard.trailingAnchor constant:-16],
        [hv.bottomAnchor constraintEqualToAnchor:hoursCard.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:hoursCard];

    NSString *current = [GSStore shared].settings[@"currentClass"] ?: @"1";
    NSDictionary *cc = [[GSStore shared] classWithId:current];
    BOOL currentNight = [cc[@"name"] containsString:@"夜"] || [cc[@"name"] containsString:@"中"] || [cc[@"name"] containsString:@"晚"];
    self.classSeg = [[UISegmentedControl alloc] initWithItems:@[@"白班", @"夜班"]];
    self.classSeg.selectedSegmentIndex = currentNight ? 1 : 0;
    self.classSeg.selectedSegmentTintColor = GSThemeColor();
    self.bonusField = [self numberField:@"0" color:GSColorHex(@"#12B76A") size:18];
    UILabel *bonusL = GSLabel(@"补贴（元/天）", GSFont(13, UIFontWeightSemibold), GSColorHex(@"#344054"));
    UIView *bonusSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *bonusRow = GSStack(@[bonusL, bonusSp, self.bonusField], UILayoutConstraintAxisHorizontal, 10);
    bonusRow.alignment = UIStackViewAlignmentCenter;
    [self.bonusField.widthAnchor constraintEqualToConstant:100].active = YES;
    GSCardView *classCard = [[GSCardView alloc] init];
    UILabel *classTitle = GSLabel(@"班制与补贴", GSFont(13, UIFontWeightSemibold), GSColorHex(@"#344054"));
    UILabel *classNote = GSLabel(@"白班自动匹配白/早班补助，夜班匹配中/晚/夜班补助；补贴按天叠加。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#667085"));
    classNote.numberOfLines = 0;
    UIStackView *cv = GSStack(@[classTitle, self.classSeg, bonusRow, classNote], UILayoutConstraintAxisVertical, 10);
    cv.translatesAutoresizingMaskIntoConstraints = NO; [classCard addSubview:cv];
    [NSLayoutConstraint activateConstraints:@[
        [cv.topAnchor constraintEqualToAnchor:classCard.topAnchor constant:16],
        [cv.leadingAnchor constraintEqualToAnchor:classCard.leadingAnchor constant:16],
        [cv.trailingAnchor constraintEqualToAnchor:classCard.trailingAnchor constant:-16],
        [cv.bottomAnchor constraintEqualToAnchor:classCard.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:classCard];

    GSCardView *optCard = [[GSCardView alloc] init];
    UILabel *optTitle = GSLabel(@"选项", GSFont(13, UIFontWeightSemibold), GSColorHex(@"#344054"));
    UILabel *blankL = GSLabel(@"只填充没有记录的日期", GSFont(13, UIFontWeightRegular), GSColorHex(@"#344054"));
    self.blankSwitch = [[UISwitch alloc] init]; self.blankSwitch.on = YES; self.blankSwitch.onTintColor = GSThemeColor();
    UIView *blankSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *blankRow = GSStack(@[blankL, blankSp, self.blankSwitch], UILayoutConstraintAxisHorizontal, 8);
    UILabel *weekendL = GSLabel(@"跳过周末", GSFont(13, UIFontWeightRegular), GSColorHex(@"#344054"));
    self.weekendSwitch = [[UISwitch alloc] init]; self.weekendSwitch.on = NO; self.weekendSwitch.onTintColor = GSThemeColor();
    UIView *weekendSp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *weekendRow = GSStack(@[weekendL, weekendSp, self.weekendSwitch], UILayoutConstraintAxisHorizontal, 8);
    UIStackView *ov = GSStack(@[optTitle, blankRow, weekendRow], UILayoutConstraintAxisVertical, 10);
    ov.translatesAutoresizingMaskIntoConstraints = NO; [optCard addSubview:ov];
    [NSLayoutConstraint activateConstraints:@[
        [ov.topAnchor constraintEqualToAnchor:optCard.topAnchor constant:16],
        [ov.leadingAnchor constraintEqualToAnchor:optCard.leadingAnchor constant:16],
        [ov.trailingAnchor constraintEqualToAnchor:optCard.trailingAnchor constant:-16],
        [ov.bottomAnchor constraintEqualToAnchor:optCard.bottomAnchor constant:-16]
    ]];
    [self.stack addArrangedSubview:optCard];

    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [applyBtn setTitle:@"应用批量工时" forState:UIControlStateNormal];
    [applyBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    applyBtn.titleLabel.font = GSFont(15, UIFontWeightSemibold);
    applyBtn.backgroundColor = GSThemeColor();
    applyBtn.layer.cornerRadius = 14;
    [applyBtn.heightAnchor constraintEqualToConstant:50].active = YES;
    [applyBtn addTarget:self action:@selector(apply) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:applyBtn];

    UIButton *leaveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [leaveBtn setTitle:@"批量设为休假" forState:UIControlStateNormal];
    [leaveBtn setTitleColor:GSColorHex(@"#B54708") forState:UIControlStateNormal];
    leaveBtn.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    leaveBtn.backgroundColor = [GSColorHex(@"#FFFAEB") colorWithAlphaComponent:1];
    leaveBtn.layer.cornerRadius = 14;
    [leaveBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    [leaveBtn addTarget:self action:@selector(applyLeave) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:leaveBtn];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearBtn setTitle:@"批量清空工时" forState:UIControlStateNormal];
    [clearBtn setTitleColor:GSColorHex(@"#B42318") forState:UIControlStateNormal];
    clearBtn.titleLabel.font = GSFont(14, UIFontWeightSemibold);
    clearBtn.backgroundColor = [GSColorHex(@"#FEF3F2") colorWithAlphaComponent:1];
    clearBtn.layer.cornerRadius = 14;
    [clearBtn.heightAnchor constraintEqualToConstant:46].active = YES;
    [clearBtn addTarget:self action:@selector(confirmClear) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:clearBtn];
}
- (UITextField *)numberField:(NSString *)text color:(UIColor *)color size:(CGFloat)size {
    UITextField *f = [[UITextField alloc] init];
    f.text = text; f.keyboardType = UIKeyboardTypeDecimalPad;
    f.font = GSFont(size, UIFontWeightBold); f.textColor = color; f.textAlignment = NSTextAlignmentCenter;
    f.backgroundColor = GSColorHex(@"#F7F9FC"); f.layer.cornerRadius = 12;
    f.translatesAutoresizingMaskIntoConstraints = NO;
    [f.heightAnchor constraintEqualToConstant:54].active = YES;
    return f;
}
- (NSString *)classIdForNight:(BOOL)night {
    if (self.classes.count == 0) return @"1";
    NSArray *keys = night ? @[@"夜", @"晚", @"中"] : @[@"白", @"早"];
    for (NSString *key in keys) {
        for (NSDictionary *c in self.classes) {
            NSString *name = c[@"name"] ?: @"";
            if ([name containsString:key]) return c[@"id"] ?: @"1";
        }
    }
    return self.classes[night ? self.classes.count - 1 : 0][@"id"] ?: @"1";
}
- (NSMutableArray *)bonusArrayForRecord:(NSMutableDictionary *)rec {
    id raw = rec[@"bt"];
    return [raw isKindOfClass:[NSArray class]] ? [raw mutableCopy] : [NSMutableArray array];
}
- (void)putBonus:(double)bonus inRecord:(NSMutableDictionary *)rec {
    NSMutableArray *bt = [self bonusArrayForRecord:rec];
    NSMutableArray *clean = [NSMutableArray array];
    for (NSDictionary *b in bt) if (![b isKindOfClass:[NSDictionary class]] || ![b[@"name"] isEqual:@"批量补贴"]) [clean addObject:b];
    if (bonus > 0) [clean addObject:[@{@"name":@"批量补贴", @"money":@(bonus), @"note":@"批量设置", @"batchBonus":@YES} mutableCopy]];
    rec[@"bt"] = clean;
}
- (void)alertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)apply {
    [self.view endEditing:YES];
    double normal = self.hoursField.text.doubleValue;
    double overtime = self.otField.text.doubleValue;
    double bonus = MAX(0, self.bonusField.text.doubleValue);
    if (normal < 0 || overtime < 0 || normal + overtime <= 0) { [self alertTitle:@"工时不对" message:@"正常工时和加班工时不能都是 0，也不能为负。"]; return; }
    if (self.selectedKeys.count == 0) { [self alertTitle:@"没有选日期" message:@"先在日历上点几天。"]; return; }
    BOOL night = self.classSeg.selectedSegmentIndex == 1;
    NSString *classId = [self classIdForNight:night];
    NSArray *keys = [self.selectedKeys.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSInteger count = 0;
    for (NSString *key in keys) {
        NSDictionary *existing = [[GSStore shared] recordForDate:key];
        if (self.blankSwitch.on && existing) continue;
        NSString *kind = GSDayKind(key);
        if (self.weekendSwitch.on && [kind isEqual:@"zm"]) continue;
        NSMutableDictionary *rec = existing ? [existing mutableCopy] : [NSMutableDictionary dictionary];
        rec[@"classId"] = classId;
        rec[@"projectId"] = [GSStore shared].settings[@"projectId"] ?: @"default";
        rec[@"type"] = kind;
        [rec removeObjectForKey:@"leave"];
        NSMutableDictionary *work = [rec[@"work"] isKindOfClass:[NSDictionary class]] ? [rec[@"work"] mutableCopy] : [NSMutableDictionary dictionary];
        for (NSString *wk in @[@"zb", @"jb", @"zm", @"jj"]) work[wk] = @0;
        NSString *workKey = [kind isEqual:@"jj"] ? @"jj" : ([kind isEqual:@"zm"] ? @"zm" : @"zb");
        work[workKey] = @(normal);
        work[@"jb"] = @(overtime);
        rec[@"work"] = work;
        [[GSStore shared] ensureAutoAllowance:rec];
        [self putBonus:bonus inRecord:rec];
        [[GSStore shared] setRecord:rec forDate:key];
        count++;
    }
    if (count == 0) { [self alertTitle:@"没有可设置的日期" message:@"选中的日期都被跳过或已有记录，检查一下筛选条件。"]; return; }
    if (self.onSaved) self.onSaved(count);
    [self dismissViewControllerAnimated:YES completion:^{ GSToast([NSString stringWithFormat:@"已批量设置 %ld 天", (long)count]); }];
}
- (void)applyLeave {
    [self.view endEditing:YES];
    if (self.selectedKeys.count == 0) { [self alertTitle:@"没有选日期" message:@"先在日历上点几天。"]; return; }
    double leaveHours = self.hoursField.text.doubleValue;
    if (leaveHours <= 0) leaveHours = 8;
    BOOL night = self.classSeg.selectedSegmentIndex == 1;
    NSString *classId = [self classIdForNight:night];
    NSArray *keys = [self.selectedKeys.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSInteger count = 0;
    for (NSString *key in keys) {
        NSDictionary *existing = [[GSStore shared] recordForDate:key];
        if (self.blankSwitch.on && existing) continue;
        NSString *kind = GSDayKind(key);
        if (self.weekendSwitch.on && [kind isEqual:@"zm"]) continue;
        NSMutableDictionary *rec = existing ? [existing mutableCopy] : [NSMutableDictionary dictionary];
        rec[@"classId"] = classId;
        rec[@"projectId"] = [GSStore shared].settings[@"projectId"] ?: @"default";
        rec[@"type"] = @"xiu";
        rec[@"work"] = [@{@"zb":@0, @"jb":@0, @"zm":@0, @"jj":@0} mutableCopy];
        rec[@"leave"] = [@{@"type":@"xiu", @"hour":@(leaveHours), @"rule":@"hour", @"multiple":@0} mutableCopy];
        [self putBonus:0 inRecord:rec];
        [[GSStore shared] setRecord:rec forDate:key];
        count++;
    }
    if (count == 0) { [self alertTitle:@"没有可设置的日期" message:@"选中的日期都被跳过或已有记录，检查一下筛选条件。"]; return; }
    if (self.onSaved) self.onSaved(count);
    [self dismissViewControllerAnimated:YES completion:^{ GSToast([NSString stringWithFormat:@"已批量休假 %ld 天", (long)count]); }];
}
- (void)confirmClear {
    if (self.selectedKeys.count == 0) { [self alertTitle:@"没有选日期" message:@"先在日历上点几天。"]; return; }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"批量清空工时" message:[NSString stringWithFormat:@"将删除选中的 %ld 天记录，不能撤销。", (long)self.selectedKeys.count] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) { [self doClear]; }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)doClear {
    NSArray *keys = [self.selectedKeys.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSInteger count = 0;
    for (NSString *key in keys) {
        if ([[GSStore shared] recordForDate:key]) { [[GSStore shared] removeRecordForDate:key]; count++; }
    }
    if (count == 0) { [self alertTitle:@"没有可清空的记录" message:@"这些日期本来就没有记录。"]; return; }
    if (self.onSaved) self.onSaved(count);
    [self dismissViewControllerAnimated:YES completion:^{ GSToast([NSString stringWithFormat:@"已清空 %ld 天工时", (long)count]); }];
}
@end
