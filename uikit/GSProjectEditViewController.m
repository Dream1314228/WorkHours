#import "GSProjectEditViewController.h"
#import "GSComponents.h"
#import "GSStore.h"

@interface GSProjectEditViewController ()
@property (nonatomic, strong) NSDictionary *project;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) UITextField *nameField, *baseField, *zbField, *jbField, *zmField, *jjField;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIScrollView *scroll;
- (UITextField *)fieldWithText:(NSString *)text keyboard:(UIKeyboardType)keyboard;
- (UIView *)row:(NSString *)title field:(UITextField *)field;
- (GSCardView *)cardWithRows:(NSArray<UIView *> *)rows;
@end

@implementation GSProjectEditViewController
- (instancetype)initWithProject:(NSDictionary *)project index:(NSInteger)index {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _project = [project copy]; _index = index; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.index >= 0 ? @"编辑项目" : @"新增项目";
    self.view.backgroundColor = GSColorHex(@"#F2F5FA");
    self.navigationController.navigationBar.tintColor = GSThemeColor();
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];
    self.stack = [[UIStackView alloc] init];
    self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 14;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:GSPageMargin],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:GSPageMargin],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-GSPageMargin],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-40]
    ]];
    NSDictionary *rates = self.project[@"rates"] ?: @{};
    self.nameField = [self fieldWithText:(self.project[@"name"] ?: @"新项目") keyboard:UIKeyboardTypeDefault];
    self.baseField = [self fieldWithText:GSNum([self.project[@"base"] doubleValue]) keyboard:UIKeyboardTypeDecimalPad];
    self.zbField = [self fieldWithText:GSNum([rates[@"zb"] doubleValue]) keyboard:UIKeyboardTypeDecimalPad];
    self.jbField = [self fieldWithText:GSNum([rates[@"jb"] doubleValue]) keyboard:UIKeyboardTypeDecimalPad];
    self.zmField = [self fieldWithText:GSNum([rates[@"zm"] doubleValue]) keyboard:UIKeyboardTypeDecimalPad];
    self.jjField = [self fieldWithText:GSNum([rates[@"jj"] doubleValue]) keyboard:UIKeyboardTypeDecimalPad];
    [self.stack addArrangedSubview:[self cardWithRows:@[
        [self row:@"项目名称" field:self.nameField],
        [self row:@"底薪" field:self.baseField],
        [self row:@"正班时薪" field:self.zbField],
        [self row:@"加班时薪" field:self.jbField],
        [self row:@"周末时薪" field:self.zmField],
        [self row:@"节假时薪" field:self.jjField]
    ]]];
    UILabel *note = GSLabel(@"底薪和四类时薪只在本项目生效；修改后，已记录工时的工资会按新费率重新计算。", GSFont(11, UIFontWeightRegular), GSTextSecondary());
    note.numberOfLines = 0;
    [self.stack addArrangedSubview:note];
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveBtn setTitle:@"保存项目" forState:UIControlStateNormal];
    [saveBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    saveBtn.titleLabel.font = GSFont(16, UIFontWeightSemibold);
    saveBtn.backgroundColor = GSThemeColor(); saveBtn.layer.cornerRadius = 14;
    [saveBtn.heightAnchor constraintEqualToConstant:50].active = YES;
    [saveBtn addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
    [self.stack addArrangedSubview:saveBtn];
}
- (UITextField *)fieldWithText:(NSString *)text keyboard:(UIKeyboardType)keyboard {
    UITextField *f = [[UITextField alloc] init];
    f.text = text; f.keyboardType = keyboard;
    f.font = GSFont(14, UIFontWeightSemibold);
    f.textColor = GSTextPrimary();
    f.textAlignment = NSTextAlignmentRight;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    return f;
}
- (UIView *)row:(NSString *)title field:(UITextField *)field {
    UIView *row = [[UIView alloc] init];
    UILabel *l = GSLabel(title, GSFont(14, UIFontWeightRegular), GSTextStrong());
    l.translatesAutoresizingMaskIntoConstraints = NO; field.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:l]; [row addSubview:field];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:44],
        [l.leadingAnchor constraintEqualToAnchor:row.leadingAnchor], [l.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor], [field.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.widthAnchor constraintEqualToConstant:150], [field.heightAnchor constraintEqualToConstant:36]
    ]];
    return row;
}
- (GSCardView *)cardWithRows:(NSArray<UIView *> *)rows {
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *v = GSStack(rows, UILayoutConstraintAxisVertical, 0);
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],
        [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:GSCardPadding],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-GSCardPadding],
        [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8]
    ]];
    return card;
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)save {
    NSString *name = self.nameField.text.length ? self.nameField.text : @"新项目";
    NSString *pid = self.project[@"id"] ?: [NSUUID UUID].UUIDString;
    NSMutableDictionary *np = [@{
        @"id": pid, @"name": name, @"mode": self.project[@"mode"] ?: @"dxjs",
        @"base": @(self.baseField.text.doubleValue),
        @"rates": [@{@"zb": @(self.zbField.text.doubleValue), @"jb": @(self.jbField.text.doubleValue),
                     @"zm": @(self.zmField.text.doubleValue), @"jj": @(self.jjField.text.doubleValue)} mutableCopy]
    } mutableCopy];
    NSMutableArray *projects = [GSStore shared].data[@"projects"];
    if (self.index >= 0 && self.index < (NSInteger)projects.count) projects[self.index] = np;
    else [projects addObject:np];
    if (![GSStore shared].settings[@"projectId"]) [GSStore shared].settings[@"projectId"] = pid;
    [[GSStore shared] save];
    if (self.onSaved) self.onSaved();
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
