#import "OTLayoutNode.h"

@implementation OTLayoutNode

- (instancetype)initWithViewName:(NSString *)viewName
                          nodeId:(NSString *)nodeId
                          fields:(NSDictionary<NSString *, NSString *> *)fields
                         stretch:(OTStretchNode *)stretch
                         flexBox:(OTFlexBox *)flexBox
                       listItems:(NSArray *)listItems
                          scroll:(BOOL)scroll
                           glass:(BOOL)glass {
    self = [super init];
    if (self) {
        _viewName = [viewName copy] ?: @"";
        _nodeId = [nodeId copy] ?: @"";
        _fields = [fields copy] ?: @{};
        _stretch = stretch;
        _flexBox = flexBox;
        _children = [NSMutableArray array];
        _listItems = [listItems copy] ?: @[];
        _scroll = scroll;
        _glass = glass;
    }
    return self;
}

@end
