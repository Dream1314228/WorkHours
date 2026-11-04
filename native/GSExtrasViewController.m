#import "GSExtrasViewController.h"
#import "GSComponents.h"
#import "GSStore.h"

@interface GSExtrasViewController ()
@property (nonatomic, assign) NSInteger year, month;
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight;
@property (nonatomic, strong) UISegmentedControl *seg;
@end
@implementation GSExtrasViewController
- (instancetype)initWithYear:(NSInteger)year month:(NSInteger)month {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _year = year; _month = month; _kind = @"bonus"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
    GSGradientView *header = [[GSGradientView alloc] init];
    header.colors = @[GSThemeColor(), GSThemeDarkColor()];
    self.header = header;
    GSAddHeaderOrbs(header);
    GSApplyHeaderCorners(header);
    self.header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.header];
    self.titleLabel = GSLabel([NSString stringWithFormat:@"补扣管理 · %ld月", (long)self.month], GSFont(17, UIFontWeightBold), UIColor.whiteColor);
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
    [self.view addSubview:self.scroll];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 10;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
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
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:10],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:18],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-18],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-30]
    ]];
    [self reload];
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    self.headerHeight.constant = self.view.safeAreaInsets.top + 52;
    self.header.startY = self.view.safeAreaInsets.top / MAX(1, self.headerHeight.constant);
}
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (UIView *)card:(NSArray<UIView *> *)views {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.whiteColor; card.layer.cornerRadius = 20;
    UIStackView *v = GSStack(views, UILayoutConstraintAxisVertical, 10);
    v.translatesAutoresizingMaskIntoConstraints = NO; [card addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    return card;
}
- (void)reload {
    for (UIView *v in self.stack.arrangedSubviews) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
    self.seg = [[UISegmentedControl alloc] initWithItems:@[@"补贴", @"扣款"]];
    self.seg.selectedSegmentIndex = [self.kind isEqual:@"bonus"] ? 0 : 1;
    self.seg.selectedSegmentTintColor = GSThemeColor();
    self.seg.backgroundColor = GSColorHex(@"#EEF3FA"); self.seg.layer.cornerRadius = 12; self.seg.clipsToBounds = YES;
    [self.seg addTarget:self action:@selector(kindChanged) forControlEvents:UIControlEventValueChanged];
    UILabel *segTitle = GSLabel(@"新增类型", GSFont(11, UIFontWeightMedium), GSColorHex(@"#5D6B82"));
    [self.stack addArrangedSubview:[self card:@[segTitle, self.seg]]];
    NSArray *bonusItems = [[GSStore shared] extrasForKind:@"bonus" year:self.year month:self.month];
    NSArray *deductItems = [[GSStore shared] extrasForKind:@"deduct" year:self.year month:self.month];
    double bonusSum = 0, deductSum = 0;
    for (NSDictionary *b in bonusItems) bonusSum += [b[@"money"] doubleValue];
    for (NSDictionary *b in deductItems) deductSum += [b[@"money"] doubleValue];
    UILabel *sumTitle = GSLabel(@"本月补扣合计", GSFont(12, UIFontWeightMedium), GSColorHex(@"#5D6B82"));
    UILabel *sumBonus = GSLabel([NSString stringWithFormat:@"补贴  +%@  ·  %ld 笔", GSMoney(bonusSum), (long)bonusItems.count], GSFont(13, UIFontWeightSemibold), GSColorHex(@"#067647"));
    UILabel *sumDeduct = GSLabel([NSString stringWithFormat:@"扣款  -%@  ·  %ld 笔", GSMoney(deductSum), (long)deductItems.count], GSFont(13, UIFontWeightSemibold), GSColorHex(@"#B42318"));
    UILabel *sumNet = GSLabel([NSString stringWithFormat:@"净额  %@", GSMoney(bonusSum - deductSum)], GSFont(14, UIFontWeightBold), GSThemeColor());
    [self.stack addArrangedSubview:[self card:@[sumTitle, sumBonus, sumDeduct, sumNet]]];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *sectionKind in @[@"bonus", @"deduct"]) {
        BOOL isBonus = [sectionKind isEqual:@"bonus"];
        NSArray *items = [[GSStore shared] extrasForKind:sectionKind year:self.year month:self.month];
        UILabel *title = GSLabel([NSString stringWithFormat:@"%@明细 · %ld 笔", isBonus ? @"补贴" : @"扣款", (long)items.count], GSFont(14, UIFontWeightBold), GSColorHex(@"#101828"));
        [rows addObject:title];
        if (items.count == 0) {
            UILabel *empty = GSLabel(isBonus ? @"本月还没有补贴" : @"本月还没有扣款", GSFont(11, UIFontWeightRegular), GSColorHex(@"#98A2B3"));
            [rows addObject:empty];
        }
        for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
            NSDictionary *b = items[i];
            NSString *bname = [b[@"name"] isKindOfClass:[NSString class]] ? b[@"name"] : (isBonus ? @"补贴" : @"扣款");
            NSString *noteValue = [b[@"note"] isKindOfClass:[NSString class]] ? b[@"note"] : @"";
            BOOL autoImport = [b[@"auto"] isKindOfClass:[NSNumber class]] && [b[@"auto"] boolValue];
            NSString *source = autoImport ? @"上月自动导入" : (noteValue.length ? noteValue : @"手动添加");
            UILabel *n = GSLabel(bname, GSFont(13, UIFontWeightSemibold), GSColorHex(@"#101828"));
            UILabel *note = GSLabel([NSString stringWithFormat:@"%@ · %@", isBonus ? @"补助" : @"扣款", source], GSFont(9, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
            double bm = fabs([b[@"money"] doubleValue]);
            UILabel *m = GSLabel([NSString stringWithFormat:@"%@%@", isBonus ? @"+" : @"-", GSMoney(bm)], GSFont(13, UIFontWeightBold), isBonus ? GSColorHex(@"#067647") : GSColorHex(@"#B42318"));
            UIButton *del = GSIconButton(@"trash", GSColorHex(@"#98A2B3"), 14);
            del.tag = (isBonus ? 10000 : 20000) + i;
            [del addTarget:self action:@selector(deleteItem:) forControlEvents:UIControlEventTouchUpInside];
            UIStackView *left = GSStack(@[n, note], UILayoutConstraintAxisVertical, 1);
            UIStackView *row = GSStack(@[left, m, del], UILayoutConstraintAxisHorizontal, 8);
            row.alignment = UIStackViewAlignmentCenter;
            [del.widthAnchor constraintEqualToConstant:26].active = YES;
            [rows addObject:row];
        }
        if (![sectionKind isEqual:@"deduct"]) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = GSColorHex(@"#F2F4F7");
            [line.heightAnchor constraintEqualToConstant:1].active = YES;
            [rows addObject:line];
        }
    }
    [self.stack addArrangedSubview:[self card:rows]];

    UITextField *name = [[UITextField alloc] init];
    name.font = GSFont(13, UIFontWeightRegular);
    name.textColor = GSColorHex(@"#101828"); name.tintColor = GSThemeColor();
    name.attributedPlaceholder = GSPlaceholder(@"名称，例如 社保 / 夜补", name.font);
    name.backgroundColor = GSColorHex(@"#F5F7FA"); name.layer.cornerRadius = 10;
    name.tag = 801; [name.heightAnchor constraintEqualToConstant:38].active = YES;
    name.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)]; name.leftViewMode = UITextFieldViewModeAlways;
    UITextField *money = [[UITextField alloc] init];
    money.keyboardType = UIKeyboardTypeDecimalPad; money.font = GSFont(13, UIFontWeightRegular);
    money.textColor = GSColorHex(@"#101828"); money.tintColor = GSThemeColor();
    money.attributedPlaceholder = GSPlaceholder(@"金额", money.font);
    money.backgroundColor = GSColorHex(@"#F5F7FA"); money.layer.cornerRadius = 10; money.tag = 802;
    [money.heightAnchor constraintEqualToConstant:38].active = YES;
    money.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)]; money.leftViewMode = UITextFieldViewModeAlways;
    UITextField *note = [[UITextField alloc] init];
    note.font = GSFont(12, UIFontWeightRegular);
    note.textColor = GSColorHex(@"#101828"); note.tintColor = GSThemeColor();
    note.attributedPlaceholder = GSPlaceholder(@"备注（可选）", note.font);
    note.backgroundColor = GSColorHex(@"#F5F7FA"); note.layer.cornerRadius = 10; note.tag = 803;
    [note.heightAnchor constraintEqualToConstant:38].active = YES;
    note.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)]; note.leftViewMode = UITextFieldViewModeAlways;
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setTitle:@"添加" forState:UIControlStateNormal]; add.titleLabel.font = GSFont(14, UIFontWeightBold);
    add.backgroundColor = GSThemeColor(); [add setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    add.layer.cornerRadius = 12; [add.heightAnchor constraintEqualToConstant:40].active = YES;
    [add addTarget:self action:@selector(addItem) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:[self card:@[GSLabel(@"新增一项", GSFont(12, UIFontWeightMedium), GSColorHex(@"#5D6B82")), name, money, note, add]]];

    UIButton *import = [UIButton buttonWithType:UIButtonTypeSystem];
    [import setTitle:@"导入上月补助和扣款" forState:UIControlStateNormal];
    import.titleLabel.font = GSFont(13, UIFontWeightSemibold);
    [import setTitleColor:GSThemeColor() forState:UIControlStateNormal];
    [import addTarget:self action:@selector(importLast) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:[self card:@[import, GSLabel(@"同时导入上月的补贴和扣款；新月份打开 App 时也会自动带入。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"))]]];
    GSAnimateStack(self.stack);
}
- (void)kindChanged { self.kind = self.seg.selectedSegmentIndex == 0 ? @"bonus" : @"deduct"; [self reload]; }
- (void)addItem {
    UITextField *name = [self.view viewWithTag:801];
    UITextField *money = [self.view viewWithTag:802];
    UITextField *note = [self.view viewWithTag:803];
    if (name.text.length == 0 || money.text.doubleValue <= 0) { GSToast(@"名称和金额要填"); return; }
    [[GSStore shared] addExtra:self.kind year:self.year month:self.month name:name.text money:money.text.doubleValue note:note.text ?: @""];
    if (self.onChanged) self.onChanged();
    GSToast(@"已添加");
    [self reload];
}
- (void)deleteItem:(UIButton *)b {
    BOOL isBonus = b.tag < 20000;
    NSInteger index = b.tag % 10000;
    [[GSStore shared] deleteExtra:isBonus ? @"bonus" : @"deduct" year:self.year month:self.month index:index];
    if (self.onChanged) self.onChanged();
    [self reload];
}
- (void)importLast {
    [[GSStore shared] importLastMonthBothToYear:self.year month:self.month];
    if (self.onChanged) self.onChanged();
    GSToast(@"已导入上月补助和扣款");
    [self reload];
}
@end
