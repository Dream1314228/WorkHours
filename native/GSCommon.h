#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

UIColor *GSColorHex(NSString *hex);
UIColor *GSColorHexA(NSString *hex, CGFloat alpha);
UIFont *GSFont(CGFloat size, UIFontWeight weight);
NSString *GSMoney(double v);
NSString *GSNum(double v);
double GSRound2(double v);
BOOL GSIsPhoneSmall(void);

NSArray<NSString *> *GSThemeKeys(void);
NSArray<NSString *> *GSThemeNames(void);
NSString *GSThemeKeyValue(void);
NSString *GSThemeNameValue(void);
NSString *GSThemeHexValue(void);
UIColor *GSThemeColor(void);
UIColor *GSThemeDarkColor(void);
UIColor *GSThemeSoftColor(void);
void GSSetThemeKey(NSString *key);
extern NSNotificationName const GSThemeDidChangeNotification;
extern NSNotificationName const GSHeaderRadiusDidChangeNotification;

NSString *GSKeyFromDate(NSDate *date);
NSDate *GSDateFromKey(NSString *key);
NSString *GSTodayKey(void);
NSString *GSWeekdayName(NSString *key);
NSString *GSRelativeDay(NSString *key);
NSInteger GSDaysInMonth(NSInteger year, NSInteger month);
NSDateComponents *GSMonthAdd(NSInteger year, NSInteger month, NSInteger delta);
NSString *GSLunarDay(NSDate *date);
NSString *GSLunarFull(NSDate *date);
NSString *GSDayKind(NSString *key);
NSString *GSKindName(NSString *kind);
NSString *GSHolidayName(NSString *key);
BOOL GSIsWorkday(NSString *key);

UIImage *GSIcon(NSString *name, CGFloat size);
void GSHaptic(void);
void GSAnimateStack(UIStackView *stack);
NSAttributedString *GSPlaceholder(NSString *text, UIFont *font);
void GSAlert(NSString *title, NSString *message);

void GSToast(NSString *message);
NS_ASSUME_NONNULL_END
