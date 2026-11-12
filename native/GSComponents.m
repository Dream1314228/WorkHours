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
        self.layer.borderWidth = 1.0 / MAX(1.0, UIScreen.mainScreen.scale);
        self.layer.borderColor = GSBorderColor().CGColor;
        self.layer.shadowColor = [UIColor colorWithRed:16/255.0 green:24/255.0 blue:40/255.0 alpha:1].CGColor;
        self.layer.shadowRadius = 14; self.layer.shadowOffset = CGSizeMake(0, 6);
        [self applyUIAppearance];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyUIAppearance) name:GSUIConfigDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)applyUIAppearance {
    NSMutableDictionary *s = [GSStore shared].settings;
    double r = s[@"cardRadius"] ? [s[@"cardRadius"] doubleValue] : 20;
    r = MAX(8, MIN(30, r));
    self.layer.cornerRadius = r;
    BOOL shadow = s[@"cardShadow"] == nil || [s[@"cardShadow"] boolValue];
    self.layer.shadowOpacity = shadow ? 0.055 : 0;
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
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

@implementation GSPressButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _pressScaleEnabled = YES;
        [self addTarget:self action:@selector(gs_touchDown) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [self addTarget:self action:@selector(gs_touchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    }
    return self;
}
- (void)gs_touchDown {
    if (!self.pressScaleEnabled || UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10 delay:0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) animations:^{
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}
- (void)gs_touchUp {
    if (!self.pressScaleEnabled || UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.68 initialSpringVelocity:0.45 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
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
        _blur.userInteractionEnabled = NO;
        [self addSubview:_blur];
        for (NSInteger i = 0; i < 4; i++) {
            UIView *pill = [[UIView alloc] init];
            pill.backgroundColor = GSThemeSoftColor();
            pill.layer.cornerRadius = 20; pill.hidden = (i != 0);
            [self addSubview:pill]; [_pills addObject:pill];
            GSPressButton *b = [[GSPressButton alloc] initWithFrame:CGRectZero];
            b.tag = i; b.pressScaleEnabled = NO;
            b.accessibilityLabel = _titles[i];
            UIImageView *icon = [[UIImageView alloc] initWithImage:GSIcon(_icons[i], 20)];
            icon.contentMode = UIViewContentModeCenter;
            icon.tintColor = GSTextSecondary();
            icon.userInteractionEnabled = NO;
            UILabel *lab = GSLabel(_titles[i], GSFont(11, UIFontWeightMedium), GSTextSecondary());
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
        CGFloat w0 = MAX(1, self.bounds.size.width / 4.0);
        _dragIndex = MAX(0, MIN(3, (NSInteger)floor(MAX(0, p.x) / w0)));
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
        UIColor *c = (i == idx) ? GSThemeColor() : GSTextSecondary();
        self.iconViews[i].tintColor = c;
        self.titleViews[i].textColor = c;
        self.titleViews[i].font = GSFont(11, (i == idx) ? UIFontWeightSemibold : UIFontWeightMedium);
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _blur.frame = self.bounds;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:26].CGPath;
    CGFloat w = self.bounds.size.width / 4.0;
    for (NSInteger i = 0; i < 4; i++) {
        _pills[i].frame = CGRectMake(i * w + 6, 6, w - 12, self.bounds.size.height - 12);
        _buttons[i].frame = CGRectMake(i * w, 0, w, self.bounds.size.height);
        _iconViews[i].frame = CGRectMake(w/2 - 10, 11, 20, 20);
        _titleViews[i].frame = CGRectMake(0, 34, w, 15);
    }
}
- (void)tap:(UIButton *)b {
    if (b.tag != self.selectedIndex) GSHaptic();
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
            UIColor *c = (i == index) ? GSThemeColor() : GSTextSecondary();
            self.iconViews[i].tintColor = c;
            self.titleViews[i].textColor = c;
            self.titleViews[i].font = GSFont(11, (i == index) ? UIFontWeightSemibold : UIFontWeightMedium);
        }
    };
    if (!animated) {
        for (UIImageView *icon in self.iconViews) icon.transform = CGAffineTransformIdentity;
        work();
        return;
    }
    if (UIAccessibilityIsReduceMotionEnabled()) {
        work();
        for (UIImageView *icon in self.iconViews) icon.transform = CGAffineTransformIdentity;
        return;
    }
    self.iconViews[index].transform = CGAffineTransformMakeScale(0.86, 0.86);
    [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.84 initialSpringVelocity:0.5 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) animations:work completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.62 initialSpringVelocity:0.7 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction) animations:^{
            for (UIImageView *icon in self.iconViews) icon.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}
@end

UILabel *GSLabel(NSString *text, UIFont *font, UIColor *color) {
    UILabel *l = [[UILabel alloc] init];
    l.text = text; l.textColor = color;
    l.lineBreakMode = NSLineBreakByTruncatingTail;
    l.adjustsFontForContentSizeCategory = NO;
    if (font) {
        BOOL hasDigit = text.length > 0 && [text rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound;
        if (hasDigit) {
            NSDictionary *traits = font.fontDescriptor.fontAttributes[UIFontDescriptorTraitsAttribute];
            CGFloat weight = [traits[UIFontWeightTrait] doubleValue];
            if (weight <= 0.001) weight = (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) ? UIFontWeightBold : UIFontWeightRegular;
            l.font = [UIFont monospacedDigitSystemFontOfSize:font.pointSize weight:weight];
        } else {
            l.font = font;
        }
    }
    return l;
}
UIStackView *GSStack(NSArray<UIView *> *views, UILayoutConstraintAxis axis, CGFloat spacing) {
    UIStackView *s = [[UIStackView alloc] initWithArrangedSubviews:views];
    s.axis = axis; s.spacing = spacing; s.alignment = UIStackViewAlignmentFill;
    return s;
}
UIButton *GSIconButton(NSString *symbol, UIColor *color, CGFloat size) {
    GSPressButton *b = [[GSPressButton alloc] initWithFrame:CGRectZero];
    [b setImage:GSIcon(symbol, size) forState:UIControlStateNormal];
    b.tintColor = color;
    b.pressScaleEnabled = NO;
    return b;
}
UIView *GSLine(void) {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = GSColorHex(@"#F0F3F8");
    return v;
}
NSAttributedString *GSAttr(NSString *text, UIFont *font, UIColor *color) {
    return [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
}


@implementation GSDonutChartView {
    UILabel *_titleLabel;
    UILabel *_subLabel;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        _titleLabel = GSLabel(@"", GSFont(20, UIFontWeightBold), GSTextPrimary());
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _subLabel = GSLabel(@"", GSFont(10, UIFontWeightRegular), GSTextSecondary());
        _subLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel]; [self addSubview:_subLabel];
    }
    return self;
}
- (void)setValues:(NSArray<NSNumber *> *)values { _values = [values copy]; [self setNeedsDisplay]; }
- (void)setColors:(NSArray<UIColor *> *)colors { _colors = [colors copy]; [self setNeedsDisplay]; }
- (void)setCenterTitle:(NSString *)t { _centerTitle = [t copy]; _titleLabel.text = t; }
- (void)setCenterSubtitle:(NSString *)t { _centerSubtitle = [t copy]; _subLabel.text = t; }
- (void)layoutSubviews {
    [super layoutSubviews];
    _titleLabel.frame = CGRectMake(0, CGRectGetMidY(self.bounds) - 24, self.bounds.size.width, 28);
    _subLabel.frame = CGRectMake(0, CGRectGetMidY(self.bounds) + 5, self.bounds.size.width, 14);
}
- (void)drawRect:(CGRect)rect {
    CGFloat side = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) - 20;
    if (side <= 0) return;
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = side / 2.0;
    CGFloat width = MAX(14, side * 0.13);
    CGFloat total = 0;
    for (NSNumber *n in self.values) total += MAX(0, n.doubleValue);
    if (total <= 0) total = 1;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, width);
    CGContextSetStrokeColorWithColor(ctx, GSColorHex(@"#EEF2F7").CGColor);
    CGContextAddArc(ctx, center.x, center.y, radius - width / 2, 0, M_PI * 2, 0);
    CGContextStrokePath(ctx);
    CGFloat start = -M_PI_2;
    for (NSInteger i = 0; i < (NSInteger)self.values.count; i++) {
        double value = MAX(0, self.values[i].doubleValue);
        if (value <= 0) continue;
        CGFloat end = start + (CGFloat)(value / total) * M_PI * 2;
        UIColor *color = i < (NSInteger)self.colors.count ? self.colors[i] : GSThemeColor();
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextAddArc(ctx, center.x, center.y, radius - width / 2, start, end, 0);
        CGContextStrokePath(ctx);
        start = end;
    }
}
@end

@implementation GSTrendChartView {
    CAGradientLayer *_fill;
    CAShapeLayer *_fillMask;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor; self.opaque = NO;
        _lineColor = GSThemeColor();
    }
    return self;
}
- (void)setValues:(NSArray<NSNumber *> *)values { _values = [values copy]; [self setNeedsDisplay]; }
- (void)setLabels:(NSArray<NSString *> *)labels { _labels = [labels copy]; [self setNeedsDisplay]; }
- (void)setLineColor:(UIColor *)lineColor { _lineColor = lineColor ?: GSThemeColor(); [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGFloat left = 4, right = 4, top = 10, bottom = 22;
    CGFloat w = CGRectGetWidth(rect) - left - right;
    CGFloat h = CGRectGetHeight(rect) - top - bottom;
    if (w <= 0 || h <= 0 || self.values.count == 0) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1);
    CGContextSetStrokeColorWithColor(ctx, GSColorHex(@"#EDF1F7").CGColor);
    for (NSInteger i = 0; i < 4; i++) {
        CGFloat y = top + h * i / 3.0;
        CGContextMoveToPoint(ctx, left, y); CGContextAddLineToPoint(ctx, left + w, y); CGContextStrokePath(ctx);
    }
    double maxV = 1;
    for (NSNumber *n in self.values) maxV = MAX(maxV, n.doubleValue);
    NSMutableArray *points = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.values.count; i++) {
        CGFloat x = left + (self.values.count <= 1 ? w / 2 : w * i / (CGFloat)(self.values.count - 1));
        CGFloat y = top + h - (CGFloat)(self.values[i].doubleValue / maxV) * h;
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    }
    UIBezierPath *line = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < (NSInteger)points.count; i++) {
        CGPoint p = [points[i] CGPointValue];
        if (i == 0) [line moveToPoint:p]; else [line addLineToPoint:p];
    }
    UIBezierPath *area = [line copy];
    CGPoint last = [points.lastObject CGPointValue], first = [points.firstObject CGPointValue];
    [area addLineToPoint:CGPointMake(last.x, top + h)];
    [area addLineToPoint:CGPointMake(first.x, top + h)];
    [area closePath];
    [[self.lineColor colorWithAlphaComponent:.12] setFill]; [area fill];
    [self.lineColor setStroke]; line.lineWidth = 2.2; line.lineJoinStyle = kCGLineJoinRound; [line stroke];
    for (NSValue *v in points) {
        CGPoint p = v.CGPointValue;
        [[UIColor whiteColor] setFill];
        UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:p radius:3 startAngle:0 endAngle:M_PI * 2 clockwise:YES];
        [dot fill];
        [self.lineColor setStroke]; dot.lineWidth = 1.8; [dot stroke];
    }
    if (self.labels.count) {
        NSDictionary *attrs = @{NSFontAttributeName:GSFont(9, UIFontWeightRegular), NSForegroundColorAttributeName:GSTextTertiary()};
        for (NSInteger i = 0; i < (NSInteger)self.labels.count; i++) {
            NSString *text = self.labels[i];
            CGFloat x = left + (self.labels.count <= 1 ? 0 : w * i / (CGFloat)(self.labels.count - 1));
            CGSize sz = [text sizeWithAttributes:attrs];
            [text drawAtPoint:CGPointMake(MAX(0, MIN(CGRectGetWidth(rect) - sz.width, x - sz.width / 2)), CGRectGetHeight(rect) - 14) withAttributes:attrs];
        }
    }
}
@end
