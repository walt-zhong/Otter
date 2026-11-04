#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class ParsedNode;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const OTLayoutErrorDomain;

static inline NSError *OTLayoutErrorMake(NSString *message) {
    return [NSError errorWithDomain:OTLayoutErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

@interface OTLayoutInput : NSObject
@property (nonatomic, assign) CGSize viewport;
@property (nonatomic, assign) CGFloat windowWidth;
@property (nonatomic, strong) ParsedNode *root;
@property (nonatomic, copy, nullable) NSDictionary *data;
@end

@interface OTLaidOutNode : NSObject
@property (nonatomic, copy) NSString *viewName;
@property (nonatomic, copy) NSString *nodeId;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *fields;
@property (nonatomic, copy) NSArray<OTLaidOutNode *> *children;
@property (nonatomic, strong, nullable) ParsedNode *item;
@property (nonatomic, copy) NSArray *listItems;
@property (nonatomic, assign) BOOL scroll;
@property (nonatomic, assign) BOOL glass;
@end

@interface OTLayoutEngine : NSObject
+ (nullable OTLaidOutNode *)layoutWithInput:(OTLayoutInput *)input
                                 expression:(id _Nullable (^)(id expression, id _Nullable data))expression
                                      error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
