#import "GSMeViewController.h"
#import "GSComponents.h"
#import "GSStore.h"
#import "GSWageCalculatorViewController.h"
#import "GSReminder.h"
#import "GSSettingsViewController.h"

@interface GSMeViewController () <UIScrollViewDelegate, UIDocumentPickerDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *statusBg;
@property (nonatomic, strong) GSGradientView *header;
@property (nonatomic, strong) UILabel *titleLabel, *subLabel;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) NSLayoutConstraint *headerHeight, *statusHeight, *titleTop;
@property (nonatomic, assign) BOOL statusDark;
@end
@implementation GSMeViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    GSBackdropView *backdrop = [[GSBackdropView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:backdrop atIndex:0];
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

    self.titleLabel = GSLabel(@"我的", GSFont(28, UIFontWeightBold), UIColor.whiteColor);
    self.subLabel = GSLabel(@"工时记录 · 本地数据", GSFont(11, UIFontWeightRegular), [UIColor colorWithWhite:1 alpha:.92]);
    for (UILabel *l in @[self.titleLabel, self.subLabel]) { l.translatesAutoresizingMaskIntoConstraints = NO; [self.header addSubview:l]; }

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
        [self.subLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.stack.topAnchor constraintEqualToAnchor:self.header.bottomAnchor constant:16],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-120]
    ]];
    [self.view bringSubviewToFront:self.statusBg];
    [self reload];
}
- (UIStatusBarStyle)preferredStatusBarStyle { return self.statusDark ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent; }
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { [self updateStatusStyle]; }
- (void)updateStatusStyle {
    CGFloat threshold = MAX(0, self.headerHeight.constant - self.view.safeAreaInsets.top);
    BOOL dark = self.scroll.contentOffset.y > threshold;
    if (dark != _statusDark) { _statusDark = dark; [self setNeedsStatusBarAppearanceUpdate]; [self.parentViewController setNeedsStatusBarAppearanceUpdate]; }
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    CGFloat top = self.view.safeAreaInsets.top;
    self.statusHeight.constant = top;
    self.headerHeight.constant = top + 100;
    self.titleTop.constant = top + 18;
    self.header.startY = top / MAX(1, self.headerHeight.constant);
    [self.header layoutIfNeeded];
    [self updateStatusStyle];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; [self updateStatusStyle]; }
- (UIButton *)rowIcon:(NSString *)icon title:(NSString *)title color:(NSString *)color action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.backgroundColor = UIColor.clearColor;
    UIView *ico = [[UIView alloc] init];
    ico.backgroundColor = GSColorHexA(color, .12); ico.layer.cornerRadius = 8;
    ico.translatesAutoresizingMaskIntoConstraints = NO; ico.userInteractionEnabled = NO;
    UIImageView *iv = [[UIImageView alloc] initWithImage:GSIcon(icon, 15)];
    iv.tintColor = GSColorHex(color); iv.contentMode = UIViewContentModeCenter;
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    [ico addSubview:iv];
    UILabel *l = GSLabel(title, GSFont(15, UIFontWeightRegular), GSColorHex(@"#101828"));
    l.translatesAutoresizingMaskIntoConstraints = NO; l.userInteractionEnabled = NO;
    UIImageView *chev = [[UIImageView alloc] initWithImage:GSIcon(@"chevron.right", 12)];
    chev.tintColor = GSColorHex(@"#667085"); chev.translatesAutoresizingMaskIntoConstraints = NO; chev.userInteractionEnabled = NO;
    [b addSubview:ico]; [b addSubview:l]; [b addSubview:chev];
    [NSLayoutConstraint activateConstraints:@[
        [b.heightAnchor constraintEqualToConstant:54],
        [ico.leadingAnchor constraintEqualToAnchor:b.leadingAnchor constant:16],
        [ico.centerYAnchor constraintEqualToAnchor:b.centerYAnchor], [ico.widthAnchor constraintEqualToConstant:30], [ico.heightAnchor constraintEqualToConstant:30],
        [iv.centerXAnchor constraintEqualToAnchor:ico.centerXAnchor], [iv.centerYAnchor constraintEqualToAnchor:ico.centerYAnchor],
        [l.leadingAnchor constraintEqualToAnchor:ico.trailingAnchor constant:10], [l.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [chev.trailingAnchor constraintEqualToAnchor:b.trailingAnchor constant:-16], [chev.centerYAnchor constraintEqualToAnchor:b.centerYAnchor],
        [chev.widthAnchor constraintEqualToConstant:14], [chev.heightAnchor constraintEqualToConstant:14]
    ]];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (GSCardView *)menuWithRows:(NSArray<UIButton *> *)rows {
    GSCardView *card = [[GSCardView alloc] init];
    UIStackView *v = [[UIStackView alloc] init];
    v.axis = UILayoutConstraintAxisVertical; v.spacing = 0; v.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:v];
    for (NSInteger i = 0; i < (NSInteger)rows.count; i++) {
        [v addArrangedSubview:rows[i]];
        if (i < (NSInteger)rows.count - 1) {
            UIView *line = GSLine(); line.translatesAutoresizingMaskIntoConstraints = NO;
            [line.heightAnchor constraintEqualToConstant:1].active = YES;
            [v addArrangedSubview:line];
        }
    }
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor constraintEqualToAnchor:card.topAnchor], [v.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor], [v.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];
    return card;
}
- (void)reload {
    for (UIView *v in self.stack.arrangedSubviews) { [self.stack removeArrangedSubview:v]; [v removeFromSuperview]; }
    GSCardView *profile = [[GSCardView alloc] init];
    UIView *avatar = [[UIView alloc] init];
    avatar.backgroundColor = GSThemeColor(); avatar.layer.cornerRadius = 18;
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *ai = GSLabel(@"工", GSFont(20, UIFontWeightBold), UIColor.whiteColor); ai.textAlignment = NSTextAlignmentCenter; ai.translatesAutoresizingMaskIntoConstraints = NO;
    [avatar addSubview:ai];
    UILabel *name = GSLabel(@"工时记录", GSFont(16, UIFontWeightBold), GSColorHex(@"#101828"));
    UILabel *sub = GSLabel(@"本地数据 · 未登录", GSFont(11, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    UILabel *badge = GSLabel(@"本地", GSFont(10, UIFontWeightSemibold), GSThemeColor());
    badge.backgroundColor = GSThemeSoftColor(); badge.layer.cornerRadius = 10; badge.clipsToBounds = YES; badge.textAlignment = NSTextAlignmentCenter;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *names = GSStack(@[name, sub], UILayoutConstraintAxisVertical, 2);
    UIView *sp = GSLabel(@"", GSFont(1, UIFontWeightRegular), UIColor.clearColor);
    UIStackView *row = GSStack(@[avatar, names, sp, badge], UILayoutConstraintAxisHorizontal, 12);
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO; [profile addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:profile.topAnchor constant:18], [row.leadingAnchor constraintEqualToAnchor:profile.leadingAnchor constant:18],
        [row.trailingAnchor constraintEqualToAnchor:profile.trailingAnchor constant:-18], [row.bottomAnchor constraintEqualToAnchor:profile.bottomAnchor constant:-18],
        [avatar.widthAnchor constraintEqualToConstant:52], [avatar.heightAnchor constraintEqualToConstant:52],
        [ai.centerXAnchor constraintEqualToAnchor:avatar.centerXAnchor], [ai.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [badge.widthAnchor constraintEqualToConstant:38], [badge.heightAnchor constraintEqualToConstant:22]
    ]];
    [self.stack addArrangedSubview:profile];

    UILabel *s1 = GSLabel(@"记录与薪资", GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    [self.stack addArrangedSubview:s1];
    NSArray *rows = @[
        [self rowIcon:@"doc.text.fill" title:@"记录设置" color:GSThemeHexValue() action:@selector(openRecord)],
        [self rowIcon:@"wallet.pass.fill" title:@"薪资与项目" color:GSThemeHexValue() action:@selector(openSalary)],
        [self rowIcon:@"function" title:@"工资计算器" color:@"#067647" action:@selector(openWageTool)],
        [self rowIcon:@"square.grid.2x2.fill" title:@"班次管理" color:@"#6941C6" action:@selector(openClasses)],
        [self rowIcon:@"clock.fill" title:@"考勤周期" color:@"#067647" action:@selector(openPeriod)]
    ];
    [self.stack addArrangedSubview:[self menuWithRows:rows]];
    [self.stack addArrangedSubview:GSLabel(@"个性化", GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"))];
    [self.stack addArrangedSubview:[self menuWithRows:@[[self rowIcon:@"gearshape.fill" title:@"软件设置" color:GSThemeHexValue() action:@selector(openSoftware)]]]];
    [self.stack addArrangedSubview:GSLabel(@"数据", GSFont(12, UIFontWeightRegular), GSColorHex(@"#5D6B82"))];
    [self.stack addArrangedSubview:[self menuWithRows:@[
        [self rowIcon:@"square.and.arrow.up.fill" title:@"导出备份 .gsjilu" color:@"#067647" action:@selector(exportData)],
        [self rowIcon:@"square.and.arrow.down.fill" title:@"导入 .gsjilu 备份" color:GSThemeHexValue() action:@selector(importData)],
        [self rowIcon:@"trash.fill" title:@"清空记录" color:@"#B42318" action:@selector(clearData)]
    ]]];
    UILabel *footer = GSLabel(@"工时记录 2.9.1 · 数据只存在本机", GSFont(10, UIFontWeightRegular), GSColorHex(@"#5D6B82"));
    footer.textAlignment = NSTextAlignmentCenter;
    [self.stack addArrangedSubview:footer];
    GSAnimateStack(self.stack);
}
- (void)push:(NSString *)page {
    GSSettingsViewController *s = [[GSSettingsViewController alloc] initWithPage:page];
    [self.navigationController pushViewController:s animated:YES];
}
- (void)openRecord { [self push:@"record"]; }
- (void)openSalary { [self push:@"salary"]; }
- (void)openProjects { [self push:@"projects"]; }
- (void)openClasses { [self push:@"classes"]; }
- (void)openPeriod { [self push:@"period"]; }
- (void)openSoftware { [self push:@"software"]; }
- (void)openWageTool {
    GSWageCalculatorViewController *c = [[GSWageCalculatorViewController alloc] init];
    [self.navigationController pushViewController:c animated:YES];
}
- (void)exportData {
    NSDictionary *backup = [[GSStore shared] backupDictionary];
    NSError *error = nil;
    NSData *plain = [NSJSONSerialization dataWithJSONObject:backup options:NSJSONWritingSortedKeys error:&error];
    NSData *d = plain ? [plain compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZFSE error:&error] : nil;
    if (!d) { GSToast(@"备份生成失败"); return; }
    NSString *name = [NSString stringWithFormat:@"工时记录备份-%@.gsjilu", GSKeyFromDate([NSDate date])];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [d writeToFile:path atomically:YES];
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)importData {
    UIDocumentPickerViewController *p = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    p.delegate = self;
    p.allowsMultipleSelection = NO;
    [self presentViewController:p animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    BOOL access = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (access) [url stopAccessingSecurityScopedResource];
    if (!data) { GSToast(@"读不到这个文件"); return; }
    NSError *error = nil;
    NSData *plain = [data decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZFSE error:&error];
    id obj = plain ? [NSJSONSerialization JSONObjectWithData:plain options:NSJSONReadingMutableContainers error:&error] : nil;
    if (![obj isKindOfClass:[NSDictionary class]]) { GSToast(@"不是有效的 .gsjilu 备份"); return; }
    NSDictionary *backup = obj;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"导入备份" message:@"导入会覆盖当前的项目、班次、设置和全部工时记录。建议先导出当前备份。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"覆盖导入" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        BOOL ok = [[GSStore shared] importBackupData:backup];
        if (!ok) { GSToast(@"备份格式不对，未导入"); return; }
        [GSReminder syncFromSettings];
        [[NSNotificationCenter defaultCenter] postNotificationName:GSThemeDidChangeNotification object:nil];
        [self reload];
        GSToast(@"备份已导入");
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {}
- (void)clearData {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"清空记录" message:@"清空全部工时和排班？项目、班次、设置会保留。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [[GSStore shared] clearAllRecords];
        GSToast(@"记录已清空");
    }]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
