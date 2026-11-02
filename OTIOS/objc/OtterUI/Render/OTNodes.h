#import <UIKit/UIKit.h>
#import "../OTCore.h"

NS_ASSUME_NONNULL_BEGIN

@class OTTemplateContext;

@interface OTBind : NSObject
@property (nonatomic, weak, nullable) OTTemplateContext *template;
@property (nonatomic, strong, nullable) JSONObject *itemData;
@property (nonatomic, copy) NSArray<NSString *> *clickNames;
@property (nonatomic, copy) NSArray<NSString *> *changeNames;
@property (nonatomic, assign) BOOL hasClick;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *fields;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, copy, nullable) NSString *idName;
@property (nonatomic, copy) NSArray<NSNumber *> *radii;
@property (nonatomic, assign) BOOL glassInteractive;
@property (nonatomic, assign) CGRect otterFrame;
@property (nonatomic, strong, nullable) ParsedNode *parsed;
@end

@interface OTViewMark : NSObject
+ (OTBind *)bind:(UIView *)view;
@end

@interface OTClickGate : NSObject <UIGestureRecognizerDelegate>
@property (class, nonatomic, readonly) OTClickGate *shared;
@end

@interface OTAbsoluteView : UIView
@property (nonatomic, strong) NSMutableArray<UIView *> *templateChildren;
- (void)placeChildren;
@end

@interface OTColumnView : OTAbsoluteView <UIGestureRecognizerDelegate>
@property (nonatomic, strong, readonly) OTAbsoluteView *scrollContent;
@property (nonatomic, assign, readonly) BOOL scrolling;
- (void)ensureScroll;
- (void)showBackdropNamed:(NSString *)name;
- (void)clearBackdrop;
@end

@interface OTRowView : OTAbsoluteView
@end

@interface OTTextView : UILabel
@property (nonatomic, assign) UIEdgeInsets textInset;
@end

@interface OTImageView : UIImageView
@property (nonatomic, copy) NSString *fit;
@property (nonatomic, strong, nullable) UIColor *placeholder;
- (void)load:(NSString *)src;
- (void)releaseImage;
@end

@interface OTSpacerView : UIView
@end

@protocol OTInputting <NSObject>
@property (nonatomic, copy) NSString *textValue;
@property (nonatomic, assign) BOOL suppressChange;
@end

@interface OTInputView : UITextField <OTInputting, UITextFieldDelegate>
@property (nonatomic, assign) BOOL suppressChange;
@property (nonatomic, strong, nullable) NSNumber *maxLength;
@end

@interface OTInputArea : UITextView <OTInputting, UITextViewDelegate>
@property (nonatomic, assign) BOOL suppressChange;
@property (nonatomic, strong, nullable) NSNumber *maxLength;
@end

@protocol OTCheckable <NSObject>
@property (nonatomic, readonly) BOOL checked;
- (void)setCheckedSilently:(BOOL)value;
@end

@interface OTCheckView : UIControl <OTCheckable>
@property (nonatomic, strong, readonly) UIView *box;
@property (nonatomic, strong, readonly) CAShapeLayer *mark;
@property (nonatomic, strong, readonly) UILabel *label;
- (void)writeBack;
@end

@interface OTRadioView : UIControl <OTCheckable>
@property (nonatomic, strong, readonly) UIView *dot;
@property (nonatomic, strong, readonly) UILabel *label;
@property (nonatomic, copy) NSString *groupName;
- (void)claimGroup;
- (void)writeSelf;
@end

@interface OTItemView : UIView
@end

@interface OTSwitchView : UIControl <OTCheckable>
@property (nonatomic, strong, readonly) UISwitch *track;
@property (nonatomic, strong, readonly) UILabel *label;
- (void)writeBack;
@end

@interface OTProgressView : UIView
@property (nonatomic, strong) UIColor *trackColor;
@property (nonatomic, strong) UIColor *barColor;
@property (nonatomic, assign) BOOL seekable;
@property (nonatomic, copy, nullable) void (^onSeekChanged)(CGFloat fraction, BOOL settled);
- (void)bindFrom:(CGFloat)from to:(CGFloat)to animate:(BOOL)animate;
- (void)setFraction:(CGFloat)fraction;
@end

@protocol OTLottiePlaying <NSObject>
- (void)setPlaying:(BOOL)playing;
@end

@interface OTLottieView : UIView <OTLottiePlaying>
- (void)bindSrc:(NSString *)src repeatCount:(NSString *)repeatCount mode:(NSString *)mode autoPlay:(BOOL)autoPlay;
- (void)releaseAnimation;
@end

@interface OTListView : UICollectionView <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) JSONArray *items;
@property (nonatomic, copy, nullable) NSString *dataKey;
@property (nonatomic, strong, nullable) ParsedNode *itemTemplate;
@property (nonatomic, assign) CGFloat gap;
@property (nonatomic, assign) BOOL horizontal;
@property (nonatomic, assign) CGFloat windowWidth;
@property (nonatomic, weak, nullable) OTTemplateContext *template;
- (instancetype)init;
- (void)applyDirection:(NSString *)direction gap:(CGFloat)gap;
- (void)setItems:(JSONArray *)array key:(nullable NSString *)key;
- (NSInteger)itemCount;
- (NSString *)itemFieldAtIndex:(NSInteger)index key:(NSString *)key;
- (void)updateItemAtIndex:(NSInteger)index fields:(NSDictionary<NSString *, NSString *> *)fields;
- (nullable NSDictionary *)firstScroll;
- (void)restoreScrollIndex:(NSInteger)index offset:(CGFloat)offset;
@end

@interface OTIme : NSObject
+ (void)dismiss:(UIView *)view;
+ (void)installOn:(UIView *)view;
@end

@interface OTToast : NSObject
+ (void)show:(NSString *)message inView:(nullable UIView *)view;
@end

@interface UIView (OtterController)
@property (nonatomic, readonly, nullable) UIViewController *ot_controller;
@end

NS_ASSUME_NONNULL_END
