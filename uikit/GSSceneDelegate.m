#import "GSSceneDelegate.h"
#import "GSRootViewController.h"

@implementation GSSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    UIWindowScene *ws = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:ws];
    GSRootViewController *root = [[GSRootViewController alloc] init];
    GSRootNavController *nav = [[GSRootNavController alloc] initWithRootViewController:root];
    nav.navigationBarHidden = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
}
@end
