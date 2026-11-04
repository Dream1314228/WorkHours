#import "GSComponents.h"
#import "GSStore.h"

void GSApplyHeaderCorners(UIView *view) {
    double r = [[GSStore shared].settings[@"headerRadius"] doubleValue];
    if (r < 0) r = 0;
    if (r > 40) r = 40;
    view.layer.cornerRadius = r;
    view.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    view.clipsToBounds = YES;
}

@implementation GSCardView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.whiteColor;
        self.layer.cornerRadius = 20;
        self.layer.shadowColor = [UIColor colorWithRed:16/255.0 green:24/255.0 blue:40/255.0 alpha:1].CGColor;
        self.layer.shadowOpacity = 0.07; self.layer.shadowRadius = 16; self.layer.shadowOffset = CGSizeMake(0, 8);
    }
    return self;
}
@end


@implementation GSBackdropView {
    CAGradientLayer *_base;
    NSMutableArray<CAGradientLayer *> *_blobs;
    CAShapeLayer *_dots;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setup];
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self setup];
    return self;
}
- (void)setup {
    self.userInteractionEnabled = NO;
    self.clipsToBounds = YES;
    _blobs = [NSMutableArray array];
    _base = [CAGradientLayer layer];
    _base.colors = @[(id)GSColorHex(@"#F2F5FA").CGColor, (id)GSColorHex(@"#EEF4FF").CGColor, (id)GSColorHex(@"#F8F5FF").CGColor];
    _base.locations = @[@0, @0.55, @1];
    _base.startPoint = CGPointMake(0, 0); _base.endPoint = CGPointMake(1, 1);
    [self.layer addSublayer:_base];
    NSArray *colors = @[@"#BFD7FF", @"#D9C8FF", @"#C8F3E3", @"#FFE0CC"];
    for (NSString *hex in colors) {
        CAGradientLayer *b = [CAGradientLayer layer];
        b.type = kCAGradientLayerRadial;
        b.colors = @[(id)[GSColorHex(hex) colorWithAlphaComponent:.50].CGColor, (id)[GSColorHex(hex) colorWithAlphaComponent:0].CGColor];
        b.locations = @[@0, @1];
        b.startPoint = CGPointMake(.5, .5); b.endPoint = CGPointMake(1, 1);
        [self.layer addSublayer:b]; [_blobs addObject:b];
    }
    _dots = [CAShapeLayer layer];
    _dots.fillColor = [UIColor colorWithWhite:1 alpha:.46].CGColor;
    [self.layer addSublayer:_dots];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    _base.frame = self.bounds;
    if (_blobs.count == 4) {
        _blobs[0].frame = CGRectMake(-w * .30, -h * .38, w * 1.05, w * 1.05);
        _blobs[1].frame = CGRectMake(w * .48, -h * .30, w * .85, w * .85);
        _blobs[2].frame = CGRectMake(-w * .34, h * .42, w * .95, w * .95);
        _blobs[3].frame = CGRectMake(w * .55, h * .36, w * .82, w * .82);
    }
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (CGFloat x = 14; x < w; x += 28) {
        for (CGFloat y = 18; y < h; y += 28) {
            [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x, y, 1.6, 1.6)]];
        }
    }
    _dots.path = path.CGPath;
    [CATransaction commit];
}
@end

void GSAddHeaderOrbs(UIView *header) {
    if (!header) return;
    header.clipsToBounds = YES;
    UIView *a = [[UIView alloc] init];
    a.backgroundColor = [UIColor colorWithWhite:1 alpha:.085];
    a.layer.cornerRadius = 110; a.userInteractionEnabled = NO;
    a.translatesAutoresizingMaskIntoConstraints = NO; [header addSubview:a];
    UIView *b = [[UIView alloc] init];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:.055];
    b.layer.cornerRadius = 80; b.userInteractionEnabled = NO;
    b.translatesAutoresizingMaskIntoConstraints = NO; [header addSubview:b];
    [NSLayoutConstraint activateConstraints:@[
        [a.widthAnchor constraintEqualToConstant:220], [a.heightAnchor constraintEqualToConstant:220],
        [a.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:86], [a.topAnchor constraintEqualToAnchor:header.topAnchor constant:-96],
        [b.widthAnchor constraintEqualToConstant:160], [b.heightAnchor constraintEqualToConstant:160],
        [b.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:-74], [b.topAnchor constraintEqualToAnchor:header.topAnchor constant:58]
    ]];
}

@implementation GSGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CAGradientLayer *l = (CAGradientLayer *)self.layer;
    l.startPoint = CGPointMake(0.5, MAX(0, MIN(1, self.startY)));
    l.endPoint = CGPointMake(0.5, 1);
}
- (void)setStartY:(CGFloat)startY { _startY = startY; [self setNeedsLayout]; }
- (void)setColors:(NSArray<UIColor *> *)colors {
    _colors = colors;
    CAGradientLayer *l = (CAGradientLayer *)self.layer;
    NSMutableArray *cg = [NSMutableArray array];
    for (UIColor *c in colors) [cg addObject:(id)c.CGColor];
    l.colors = cg;
    l.startPoint = CGPointMake(0.5, MAX(0, MIN(1, self.startY))); l.endPoint = CGPointMake(0.5, 1);
}
@end

@implementation GSPillButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.titleLabel.font = GSFont(14, UIFontWeightSemibold);
        self.layer.cornerRadius = 12;
        self.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    }
    return self;
}
@end

@interface GSGlassTabBar ()
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) NSMutableArray<UIButton *> *buttons;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *iconViews;
@property (nonatomic, strong) NSMutableArray<UILabel *> *titleViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *pills;
@property (nonatomic, strong) NSArray *titles;
@property (nonatomic, strong) NSArray *icons;
@property (nonatomic, strong) UIView *dragPill;
@property (nonatomic, assign) NSInteger dragIndex;
@property (nonatomic, assign) BOOL dragging;
@end
@implementation GSGlassTabBar
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _titles = @[@"记录", @"统计", @"排班", @"我的"];
        _icons = @[@"calendar", @"chart.bar.fill", @"square.grid.2x2", @"person.fill"];
        _buttons = [NSMutableArray array]; _pills = [NSMutableArray array];
        _iconViews = [NSMutableArray array]; _titleViews = [NSMutableArray array];
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:0.72];
        self.layer.cornerRadius = 26;
        self.layer.shadowColor = [UIColor colorWithRed:16/255.0 green:24/255.0 blue:40/255.0 alpha:1].CGColor;
        self.layer.shadowOpacity = 0.14; self.layer.shadowRadius = 24; self.layer.shadowOffset = CGSizeMake(0, 10);
        _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
        _blur.layer.cornerRadius = 26; _blur.clipsToBounds = YES;
        [self addSubview:_blur];
        for (NSInteger i = 0; i < 4; i++) {
            UIView *pill = [[UIView alloc] init];
            pill.backgroundColor = GSThemeSoftColor();
            pill.layer.cornerRadius = 20; pill.hidden = (i != 0);
            [self addSubview:pill]; [_pills addObject:pill];
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.tag = i;
            UIImageView *icon = [[UIImageView alloc] initWithImage:GSIcon(_icons[i], 20)];
            icon.contentMode = UIViewContentModeCenter;
            icon.tintColor = GSColorHex(@"#667085");
            icon.userInteractionEnabled = NO;
            UILabel *lab = GSLabel(_titles[i], GSFont(10, UIFontWeightMedium), GSColorHex(@"#667085"));
            lab.textAlignment = NSTextAlignmentCenter;
            lab.userInteractionEnabled = NO;
            [b addSubview:icon]; [b addSubview:lab];
            [_iconViews addObject:icon]; [_titleViews addObject:lab];
            [b addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:b]; [_buttons addObject:b];
        }
        _dragPill = [[UIView alloc] init];
        _dragPill.backgroundColor = GSThemeSoftColor();
        _dragPill.layer.cornerRadius = 20;
        _dragPill.hidden = YES;
        _dragPill.userInteractionEnabled = NO;
        [self insertSubview:_dragPill atIndex:1];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        pan.maximumNumberOfTouches = 1;
        [self addGestureRecognizer:pan];
        [self setSelectedIndex:0 animated:NO];
    }
    return self;
}
- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (self.bounds.size.width <= 0) return;
    CGPoint p = [g locationInView:self];
    if (g.state == UIGestureRecognizerStateBegan) {
        _dragging = YES;
        _dragIndex = self.selectedIndex;
        for (UIView *pill in self.pills) pill.hidden = YES;
        _dragPill.hidden = NO;
        _dragPill.alpha = 1;
        [self updateDragPill:p];
    } else if (g.state == UIGestureRecognizerStateChanged) {
        [self updateDragPill:p];
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        NSInteger old = self.selectedIndex;
        NSInteger idx = _dragIndex;
        _dragging = NO;
        _dragPill.hidden = YES;
        [self setSelectedIndex:idx animated:YES];
        if (idx != old && self.onSelect) self.onSelect(idx);
    }
}
- (void)updateDragPill:(CGPoint)p {
    CGFloat w = self.bounds.size.width / 4.0;
    if (w <= 0) return;
    CGFloat x = MAX(w / 2.0, MIN(self.bounds.size.width - w / 2.0, p.x));
    CGFloat pillW = w - 12;
    _dragPill.frame = CGRectMake(x - pillW / 2.0, 6, pillW, self.bounds.size.height - 12);
    NSInteger idx = (NSInteger)floor(MAX(0, MIN(self.bounds.size.width - 0.001, p.x)) / w);
    idx = MAX(0, MIN(3, idx));
    if (idx != _dragIndex) { _dragIndex = idx; GSHaptic(); }
    for (NSInteger i = 0; i < 4; i++) {
        UIColor *c = (i == idx) ? GSThemeColor() : GSColorHex(@"#667085");
        self.iconViews[i].tintColor = c;
        self.titleViews[i].textColor = c;
        self.titleViews[i].font = GSFont(10, (i == idx) ? UIFontWeightSemibold : UIFontWeightMedium);
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _blur.frame = self.bounds;
    CGFloat w = self.bounds.size.width / 4.0;
    for (NSInteger i = 0; i < 4; i++) {
        _pills[i].frame = CGRectMake(i * w + 6, 6, w - 12, self.bounds.size.height - 12);
        _buttons[i].frame = CGRectMake(i * w, 0, w, self.bounds.size.height);
        _iconViews[i].frame = CGRectMake(w/2 - 10, 11, 20, 20);
        _titleViews[i].frame = CGRectMake(0, 35, w, 14);
    }
}
- (void)tap:(UIButton *)b {
    [self setSelectedIndex:b.tag animated:YES];
    if (self.onSelect) self.onSelect(b.tag);
}
- (void)setSelectedIndex:(NSInteger)index {
    [self setSelectedIndex:index animated:NO];
}
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated {
    _selectedIndex = index;
    _dragging = NO;
    _dragPill.hidden = YES;
    void (^work)(void) = ^{
        CGFloat w = self.bounds.size.width / 4.0;
        for (NSInteger i = 0; i < 4; i++) {
            self.pills[i].hidden = (i != index);
            if (w > 0) self.pills[i].frame = CGRectMake(i * w + 6, 6, w - 12, self.bounds.size.height - 12);
            self.buttons[i].selected = (i == index);
            UIColor *c = (i == index) ? GSThemeColor() : GSColorHex(@"#667085");
            self.iconViews[i].tintColor = c;
            self.titleViews[i].textColor = c;
            self.titleViews[i].font = GSFont(10, (i == index) ? UIFontWeightSemibold : UIFontWeightMedium);
        }
    };
    if (!animated) {
        for (UIImageView *icon in self.iconViews) icon.transform = CGAffineTransformIdentity;
        work();
        return;
    }
    self.iconViews[index].transform = CGAffineTransformMakeScale(0.84, 0.84);
    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:work completion:^(BOOL finished) {
        [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            for (UIImageView *icon in self.iconViews) icon.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}
@end

UILabel *GSLabel(NSString *text, UIFont *font, UIColor *color) {
    UILabel *l = [[UILabel alloc] init];
    l.text = text; l.font = font; l.textColor = color;
    return l;
}
UIStackView *GSStack(NSArray<UIView *> *views, UILayoutConstraintAxis axis, CGFloat spacing) {
    UIStackView *s = [[UIStackView alloc] initWithArrangedSubviews:views];
    s.axis = axis; s.spacing = spacing; s.alignment = UIStackViewAlignmentFill;
    return s;
}
UIButton *GSIconButton(NSString *symbol, UIColor *color, CGFloat size) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setImage:GSIcon(symbol, size) forState:UIControlStateNormal];
    b.tintColor = color;
    return b;
}
UIView *GSLine(void) {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = GSColorHex(@"#F2F5FA");
    return v;
}
NSAttributedString *GSAttr(NSString *text, UIFont *font, UIColor *color) {
    return [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
}
