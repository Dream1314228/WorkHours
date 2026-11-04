#import "GSWageCalculatorViewController.h"
#import "GSComponents.h"
#import "GSStore.h"

@interface GSWageCalculatorViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UILabel *resultLabel, *detailLabel;
@property (nonatomic, strong) NSArray<UITextField *> *fields;
@property (nonatomic, strong) NSDictionary *rates;
- (void)recalc;
@end

@implementation GSWageCalculatorViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"工资计算器";
    self.view.backgroundColor = GSColorHex(@"#F2F5FA");
    NSDictionary *project = [[GSStore shared] projectWithId:[GSStore shared].settings[@"projectId"] ?: @"default"];
    self.rates = project[@"rates"] ?: @{};
    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO; self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 14;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO; [self.scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:16],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-40]
    ]];
    UILabel *title = GSLabel([NSString stringWithFormat:@"按「%@」费率试算", project[@"name"] ?: @"当前项目"], GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    [self.stack addArrangedSubview:title];

    NSMutableArray *fields = [NSMutableArray array];
    NSArray *titles = @[@"底薪（元）", @"正班时数", @"加班时数", @"周末时数", @"节假时数", @"补贴（元）", @"扣款（元）"];
    NSArray *values = @[GSNum([project[@"base"] doubleValue]), @"0", @"0", @"0", @"0", @"0", @"0"];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIView *row = [[UIView alloc] init];
        UILabel *l = GSLabel(titles[i], GSFont(13, UIFontWeightRegular), GSColorHex(@"#344054"));
        UITextField *f = [[UITextField alloc] init];
        f.text = values[i]; f.keyboardType = UIKeyboardTypeDecimalPad; f.textAlignment = NSTextAlignmentRight;
        f.font = GSFont(15, UIFontWeightSemibold); f.textColor = GSColorHex(@"#101828");
        f.tag = 500 + i; f.clearButtonMode = UITextFieldViewModeWhileEditing;
        [f addTarget:self action:@selector(recalc) forControlEvents:UIControlEventEditingChanged];
        l.translatesAutoresizingMaskIntoConstraints = NO; f.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:l]; [row addSubview:f];
        [NSLayoutConstraint activateConstraints:@[
            [row.heightAnchor constraintEqualToConstant:44],
            [l.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [l.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [f.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [f.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [f.widthAnchor constraintEqualToConstant:140], [f.heightAnchor constraintEqualToConstant:36]
        ]];
        [rows addObject:row]; [fields addObject:f];
    }
    self.fields = fields;
    GSCardView *form = [[GSCardView alloc] init];
    UIStackView *formStack = GSStack(rows, UILayoutConstraintAxisVertical, 0);
    formStack.translatesAutoresizingMaskIntoConstraints = NO; [form addSubview:formStack];
    [NSLayoutConstraint activateConstraints:@[
        [formStack.topAnchor constraintEqualToAnchor:form.topAnchor constant:8], [formStack.leadingAnchor constraintEqualToAnchor:form.leadingAnchor constant:16],
        [formStack.trailingAnchor constraintEqualToAnchor:form.trailingAnchor constant:-16], [formStack.bottomAnchor constraintEqualToAnchor:form.bottomAnchor constant:-8]
    ]];
    [self.stack addArrangedSubview:form];

    GSCardView *resultCard = [[GSCardView alloc] init];
    self.resultLabel = GSLabel(@"¥0.00", GSFont(34, UIFontWeightBold), GSThemeColor());
    self.resultLabel.textAlignment = NSTextAlignmentCenter;
    self.detailLabel = GSLabel(@"", GSFont(11, UIFontWeightRegular), GSColorHex(@"#667085"));
    self.detailLabel.textAlignment = NSTextAlignmentCenter; self.detailLabel.numberOfLines = 0;
    UIStackView *rs = GSStack(@[GSLabel(@"预计工资", GSFont(11, UIFontWeightMedium), GSColorHex(@"#667085")), self.resultLabel, self.detailLabel], UILayoutConstraintAxisVertical, 4);
    rs.translatesAutoresizingMaskIntoConstraints = NO; [resultCard addSubview:rs];
    [NSLayoutConstraint activateConstraints:@[
        [rs.topAnchor constraintEqualToAnchor:resultCard.topAnchor constant:18], [rs.leadingAnchor constraintEqualToAnchor:resultCard.leadingAnchor constant:16],
        [rs.trailingAnchor constraintEqualToAnchor:resultCard.trailingAnchor constant:-16], [rs.bottomAnchor constraintEqualToAnchor:resultCard.bottomAnchor constant:-18]
    ]];
    [resultCard.heightAnchor constraintGreaterThanOrEqualToConstant:130].active = YES;
    [self.stack addArrangedSubview:resultCard];
    UILabel *note = GSLabel(@"只做估算：按当前项目底薪/时薪计算，不含社保、个税和其他扣款规则。", GSFont(10, UIFontWeightRegular), GSColorHex(@"#667085"));
    note.numberOfLines = 0; [self.stack addArrangedSubview:note];
    [self recalc];
}
- (double)valueAt:(NSInteger)i { return self.fields[i].text.doubleValue; }
- (void)recalc {
    if (self.fields.count < 7) return;
    double base = [self valueAt:0], zb = [self valueAt:1], jb = [self valueAt:2], zm = [self valueAt:3], jj = [self valueAt:4], bonus = [self valueAt:5], deduct = [self valueAt:6];
    double total = base + zb * [self.rates[@"zb"] doubleValue] + jb * [self.rates[@"jb"] doubleValue] + zm * [self.rates[@"zm"] doubleValue] + jj * [self.rates[@"jj"] doubleValue] + bonus - deduct;
    self.resultLabel.text = GSMoney(total);
    self.detailLabel.text = [NSString stringWithFormat:@"底薪 %@ + 正班 %@ + 加班 %@ + 周末 %@ + 节假 %@ + 补贴 %@ - 扣款 %@",
                             GSMoney(base), GSMoney(zb * [self.rates[@"zb"] doubleValue]), GSMoney(jb * [self.rates[@"jb"] doubleValue]),
                             GSMoney(zm * [self.rates[@"zm"] doubleValue]), GSMoney(jj * [self.rates[@"jj"] doubleValue]), GSMoney(bonus), GSMoney(deduct)];
}
@end
