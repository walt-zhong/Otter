#import "OTAttrBinding.h"
#import "OTLayoutNode.h"

NS_ASSUME_NONNULL_BEGIN

BOOL OTWrapTextHeightSettle(OTLayoutNode *root,
                            CGSize viewport,
                            float windowWidthPoints,
                            OTLayoutExpressionBlock _Nullable expression,
                            BOOL (^compute)(NSError **error),
                            NSError **error);

NS_ASSUME_NONNULL_END
