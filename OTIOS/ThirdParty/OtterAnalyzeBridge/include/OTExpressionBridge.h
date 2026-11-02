//
//  OTExpressionBridge.h
//  Otter expression engine, ObjC++ bridge.
//
//  Call structure follows the vendored GaiaX iOS bridge
//  (GXAnalyzeImpl / GXNativeAnalyze / GXContext), Apache-2.0,
//  commit 32876389b6a447bb8d6b77ce12a70d0f1fc57dbf.
//  Value and function semantics follow
//  OTAndroid ExpressionWrapper.kt and OTJniAnalyze.cpp.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OTEvalKind) {
    OTEvalKindBool = 1,
    OTEvalKindLong = 2,
    OTEvalKindFloat = 3,
    OTEvalKindString = 4,
    OTEvalKindArray = 5,
    OTEvalKindMap = 6,
};

/// One evaluated value. Null results are a nil box, not a kind.
@interface OTEvalBox : NSObject
@property (nonatomic, readonly) OTEvalKind kind;
@property (nonatomic, readonly) BOOL boolValue;
@property (nonatomic, readonly) int64_t longValue;
@property (nonatomic, readonly) float floatValue;
@property (nonatomic, readonly, nullable) id objectValue;
@end

/// Owns one OTAnalyze subclass. String expressions only; the Swift
/// ExpressionEngine applies ExpressionWrapper / OTAnalyze.getResult.
@interface OTExpressionBridge : NSObject

- (nullable OTEvalBox *)evaluateString:(NSString *)expression data:(nullable id)data;

@end

NS_ASSUME_NONNULL_END
