#import <UIKit/UIKit.h>
#import "GSCommon.h"

NS_ASSUME_NONNULL_BEGIN
@interface GSCardView : UIView
@end
@interface GSBackdropView : UIView
@end
void GSAddHeaderOrbs(UIView *header);
void GSApplyHeaderCorners(UIView *view);
@interface GSGradientView : UIView
@property (nonatomic, copy) NSArray<UIColor *> *colors;
@property (nonatomic, assign) CGFloat startY;
@end
@interface GSGlassTabBar : UIView
@property (nonatomic, copy) void (^onSelect)(NSInteger index);
@property (nonatomic, assign) NSInteger selectedIndex;
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;
@end
@interface GSPillButton : UIButton
@end
UILabel *GSLabel(NSString *text, UIFont *font, UIColor *color);
UIStackView *GSStack(NSArray<UIView *> *views, UILayoutConstraintAxis axis, CGFloat spacing);
UIButton *GSIconButton(NSString *symbol, UIColor *color, CGFloat size);
UIView *GSLine(void);
NSAttributedString *GSAttr(NSString *text, UIFont *font, UIColor *color);
NS_ASSUME_NONNULL_END
