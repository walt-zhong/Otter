#import "OTFlexBox.h"
#import "OTStretchNode.h"

@class ParsedNode;

NS_ASSUME_NONNULL_BEGIN

@interface OTLayoutNode : NSObject
@property (nonatomic, copy, readonly) NSString *viewName;
@property (nonatomic, copy, readonly) NSString *nodeId;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *fields;
@property (nonatomic, strong, readonly) OTStretchNode *stretch;
@property (nonatomic, strong, readonly) OTFlexBox *flexBox;
@property (nonatomic, strong, readonly) NSMutableArray<OTLayoutNode *> *children;
@property (nonatomic, weak, nullable) OTLayoutNode *parent;
@property (nonatomic, strong, nullable) ParsedNode *item;
@property (nonatomic, copy) NSArray *listItems;
@property (nonatomic, assign) BOOL scroll;
@property (nonatomic, assign) BOOL glass;
@property (nonatomic, strong, nullable) OTStretchLayout *layout;

- (instancetype)initWithViewName:(NSString *)viewName
                          nodeId:(NSString *)nodeId
                          fields:(NSDictionary<NSString *, NSString *> *)fields
                         stretch:(OTStretchNode *)stretch
                         flexBox:(OTFlexBox *)flexBox
                       listItems:(NSArray *)listItems
                          scroll:(BOOL)scroll
                           glass:(BOOL)glass;
@end

NS_ASSUME_NONNULL_END
