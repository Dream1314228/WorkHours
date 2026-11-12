#import "GSRootViewController.h"
#import "GSReminder.h"
#import "GSComponents.h"
#import "GSRecordViewController.h"
#import "GSStatsViewController.h"
#import "GSScheduleViewController.h"
#import "GSMeViewController.h"

@interface GSRootNavController ()
@end
@implementation GSRootNavController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.interactivePopGestureRecognizer.enabled = YES;
    self.interactivePopGestureRecognizer.delegate = nil;
}
- (UIViewController *)childForStatusBarStyle { return self.topViewController; }
- (UIViewController *)childForStatusBarHidden { return self.topViewController; }
@end

@interface GSRootViewController ()
@property (nonatomic, strong) NSArray<UIViewController *> *tabs;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, strong) GSGlassTabBar *tabbar;
@end
@implementation GSRootViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GSColorHex(@"#F2F5FA");
    self.content = [[UIView alloc] initWithFrame:self.view.bounds];
    self.content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.content];
    [self buildTabs];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeDidChange:) name:GSThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeDidChange:) name:GSHeaderRadiusDidChangeNotification object:nil];
    [GSReminder syncFromSettings];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)buildTabs {
    for (UIViewController *c in self.tabs) {
        [c willMoveToParentViewController:nil];
        [c.view removeFromSuperview];
        [c removeFromParentViewController];
    }
    [self.tabbar removeFromSuperview];
    self.tabs = @[[[GSRecordViewController alloc] init], [[GSStatsViewController alloc] init], [[GSScheduleViewController alloc] init], [[GSMeViewController alloc] init]];
    self.selectedIndex = 0;
    UIViewController *first = self.tabs[0];
    [self addChildViewController:first];
    first.view.frame = self.content.bounds;
    first.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.content addSubview:first.view];
    [first didMoveToParentViewController:self];
    self.tabbar = [[GSGlassTabBar alloc] initWithFrame:CGRectZero];
    __weak typeof(self) weakSelf = self;
    self.tabbar.onSelect = ^(NSInteger index) { [weakSelf selectTab:index]; };
    [self.view addSubview:self.tabbar];
    [self.view bringSubviewToFront:self.tabbar];
    [self setNeedsStatusBarAppearanceUpdate];
    [self.view setNeedsLayout];
}
- (void)themeDidChange:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presented = self.presentedViewController;
        if (presented) {
            [presented dismissViewControllerAnimated:NO completion:^{ [self buildTabs]; }];
        } else {
            [self buildTabs];
        }
    });
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [GSReminder syncFromSettings];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.content.frame = self.view.bounds;
    CGFloat h = 64;
    CGFloat bottom = self.view.safeAreaInsets.bottom;
    self.tabbar.frame = CGRectMake(14, CGRectGetHeight(self.view.bounds) - h - bottom - 8, CGRectGetWidth(self.view.bounds) - 28, h);
}
- (void)selectTab:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;
    if (index == self.selectedIndex) return;
    UIViewController *old = self.tabs[self.selectedIndex];
    UIViewController *nw = self.tabs[index];
    [old willMoveToParentViewController:nil];
    [self addChildViewController:nw];
    nw.view.frame = self.content.bounds;
    nw.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    nw.view.alpha = reduceMotion ? 1 : 0;
    nw.view.transform = reduceMotion ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 6);
    [self.content addSubview:nw.view];
    self.selectedIndex = index;
    [self setNeedsStatusBarAppearanceUpdate];
    if (reduceMotion) {
        [old.view removeFromSuperview];
        [old removeFromParentViewController];
        [nw didMoveToParentViewController:self];
        return;
    }
    [UIView animateWithDuration:0.26 delay:0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) animations:^{
        nw.view.alpha = 1; nw.view.transform = CGAffineTransformIdentity;
        old.view.alpha = 0;
    } completion:^(BOOL finished) {
        [old.view removeFromSuperview];
        [old removeFromParentViewController];
        [nw didMoveToParentViewController:self];
    }];
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    return [self.tabs[self.selectedIndex] preferredStatusBarStyle];
}
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation { return UIStatusBarAnimationFade; }
@end
