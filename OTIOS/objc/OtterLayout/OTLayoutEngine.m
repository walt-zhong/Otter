#import "OTLayoutEngine.h"

#import "OTAttrBinding.h"
#import "OTFlexBox.h"
#import "OTLayoutNode.h"
#import "OTSize.h"
#import "OTWrapTextHeight.h"
#import "TemplateJsonParser.h"

static BOOL OTComputeLayout(OTLayoutNode *root, CGSize viewport, NSError **error);
static BOOL OTApplyLayout(OTLayoutNode *node, OTStretchLayout *layout, NSError **error);
static OTLayoutNode *OTBuildLayoutNode(ParsedNode *node,
                                       OTLayoutNode *parent,
                                       NSDictionary *data,
                                       OTLayoutExpressionBlock expression,
                                       float windowWidthPoints,
                                       NSError **error);
static CGRect OTFrameFromLayout(OTStretchLayout *layout);
static OTLaidOutNode *OTLaidOutTree(OTLayoutNode *node);

NSErrorDomain const OTLayoutErrorDomain = @"OTLayoutError";

@implementation OTLayoutInput
@end

@implementation OTLaidOutNode

- (instancetype)init {
    self = [super init];
    if (self) {
        _viewName = @"";
        _nodeId = @"";
        _fields = @{};
        _children = @[];
        _listItems = @[];
    }
    return self;
}

@end

@implementation OTLayoutEngine

+ (nullable OTLaidOutNode *)layoutWithInput:(OTLayoutInput *)input
                                 expression:(id _Nullable (^)(id expression, id _Nullable data))expression
                                      error:(NSError **)error {
    if (!input.root) {
        if (error) {
            *error = OTLayoutErrorMake(@"layout input is missing a root");
        }
        return nil;
    }
    OTLayoutExpressionBlock eval = nil;
    if (expression) {
        eval = [expression copy];
    } else {
        eval = ^id(id expr, id data) {
            (void)expr;
            (void)data;
            return nil;
        };
    }
    float windowWidth = (float)input.windowWidth;
    NSDictionary *data = input.data ?: @{};
    NSError *buildError = nil;
    OTLayoutNode *root = OTBuildLayoutNode(input.root, nil, data, eval, windowWidth, &buildError);
    if (!root) {
        if (error) {
            *error = buildError;
        }
        return nil;
    }
    CGSize viewport = input.viewport;
    BOOL (^compute)(NSError **) = ^BOOL(NSError **computeError) {
        return OTComputeLayout(root, viewport, computeError);
    };
    NSError *settleError = nil;
    if (!OTWrapTextHeightSettle(root, viewport, windowWidth, eval, compute, &settleError)) {
        if (error) {
            *error = settleError;
        }
        return nil;
    }
    return OTLaidOutTree(root);
}

@end

static BOOL OTComputeLayout(OTLayoutNode *root, CGSize viewport, NSError **error) {
    // `Node.safeComputeLayout` subtracts 0.01 so an integer viewport does not
    // collapse nested nodes. Both axes stay concrete. There is no free axis.
    float width = (float)viewport.width - 0.01f;
    float height = (float)viewport.height - 0.01f;
    OTStretchLayout *layout = [root.stretch computeLayoutWidth:width height:height];
    if (!layout) {
        if (error) {
            *error = OTLayoutErrorMake(@"stretch computeLayout returned nil");
        }
        return NO;
    }
    return OTApplyLayout(root, layout, error);
}

static BOOL OTApplyLayout(OTLayoutNode *node, OTStretchLayout *layout, NSError **error) {
    node.layout = layout;
    if (layout.children.count != node.children.count) {
        if (error) {
            *error = OTLayoutErrorMake([NSString stringWithFormat:
                @"stretch layout child count %lu does not match node %@ children %lu",
                (unsigned long)layout.children.count,
                node.nodeId ?: @"",
                (unsigned long)node.children.count]);
        }
        return NO;
    }
    for (NSUInteger index = 0; index < node.children.count; index++) {
        if (!OTApplyLayout(node.children[index], layout.children[index], error)) {
            return NO;
        }
    }
    return YES;
}

static OTLayoutNode *OTBuildLayoutNode(ParsedNode *node,
                                       OTLayoutNode *parent,
                                       NSDictionary *data,
                                       OTLayoutExpressionBlock expression,
                                       float windowWidthPoints,
                                       NSError **error) {
    OTBoundAttrs *bound = OTBindAttributes(node.viewName ?: @"",
                                           node.attrs,
                                           data,
                                           expression);
    OTFlexBox *flex = [OTFlexBox flexBoxWithViewName:node.viewName ?: @""
                                             fields:bound.fields
                                 windowWidthPoints:windowWidthPoints
                                              error:error];
    if (!flex) {
        return nil;
    }
    OTStretchNode *stretch = [[OTStretchNode alloc] initWithStyle:[flex makeStyle] children:@[]];
    OTLayoutNode *layoutNode = [[OTLayoutNode alloc] initWithViewName:node.viewName ?: @""
                                                               nodeId:[node id] ?: @""
                                                               fields:bound.fields
                                                              stretch:stretch
                                                              flexBox:flex
                                                            listItems:bound.listItems
                                                               scroll:bound.scroll
                                                                glass:bound.glass];
    layoutNode.parent = parent;
    // `NodeTreePrepare` keeps the list item template and does not stretch it
    // with the page. Expressions inside the item stay on that template.
    layoutNode.item = node.item;
    for (ParsedNode *child in node.children) {
        OTLayoutNode *childNode = OTBuildLayoutNode(child, layoutNode, data, expression, windowWidthPoints, error);
        if (!childNode) {
            return nil;
        }
        [layoutNode.children addObject:childNode];
        [layoutNode.stretch addChild:childNode.stretch];
    }
    return layoutNode;
}

static CGRect OTFrameFromLayout(OTStretchLayout *layout) {
    if (!layout) {
        return CGRectZero;
    }
    return CGRectMake((CGFloat)OTJavaRoundToInt(layout.x),
                      (CGFloat)OTJavaRoundToInt(layout.y),
                      (CGFloat)OTJavaRoundToInt(layout.width),
                      (CGFloat)OTJavaRoundToInt(layout.height));
}

static OTLaidOutNode *OTLaidOutTree(OTLayoutNode *node) {
    OTLaidOutNode *laidOut = [[OTLaidOutNode alloc] init];
    laidOut.viewName = node.viewName;
    laidOut.nodeId = node.nodeId;
    laidOut.frame = OTFrameFromLayout(node.layout);
    laidOut.fields = node.fields;
    NSMutableArray<OTLaidOutNode *> *children = [NSMutableArray arrayWithCapacity:node.children.count];
    for (OTLayoutNode *child in node.children) {
        [children addObject:OTLaidOutTree(child)];
    }
    laidOut.children = children;
    laidOut.item = node.item;
    laidOut.listItems = node.listItems ?: @[];
    laidOut.scroll = node.scroll;
    laidOut.glass = node.glass;
    return laidOut;
}
