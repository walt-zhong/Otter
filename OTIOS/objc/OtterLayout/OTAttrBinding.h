#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^OTLayoutExpressionBlock)(id expression, id _Nullable data);

@interface OTBoundAttrs : NSObject
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *fields;
@property (nonatomic, assign) BOOL scroll;
@property (nonatomic, assign) BOOL glass;
@property (nonatomic, copy) NSArray *listItems;
@end

OTBoundAttrs *OTBindAttributes(NSString *viewName,
                               NSDictionary<NSString *, NSString *> *_Nullable attrs,
                               id _Nullable data,
                               OTLayoutExpressionBlock _Nullable expression);

/// A null result for a string expression is the original text.
NSString *OTExtractExpValue(NSString *raw,
                            id _Nullable data,
                            OTLayoutExpressionBlock _Nullable expression);

NS_ASSUME_NONNULL_END
