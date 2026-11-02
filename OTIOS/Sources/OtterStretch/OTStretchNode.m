#import "OTStretchNode.h"

static void *OTCreateLayout(const float *floats) {
    const float *ignored = NULL;
    OTStretchLayout *layout = [OTStretchLayout fromFloats:floats consumed:&ignored];
    return (__bridge_retained void *)layout;
}

static StretchSize OTMeasureThunk(const void *context, float width, float height) {
    OTStretchMeasure measure = (__bridge OTStretchMeasure)context;
    return measure(width, height);
}

@interface OTStretchNode ()
@property (nonatomic, assign) void *rustptr;
@property (nonatomic, copy, nullable) OTStretchMeasure measureBlock;
@property (nonatomic, strong) NSMutableArray<OTStretchNode *> *mutableChildren;
@end

@implementation OTStretchNode

- (instancetype)initWithStyle:(OTStretchStyle *)style children:(NSArray<OTStretchNode *> *)children {
    self = [super init];
    if (self) {
        _style = style;
        _mutableChildren = [NSMutableArray array];
        _rustptr = [[OTStretch shared] createNodeWithStyle:style.rustptr];
        for (OTStretchNode *child in children) {
            [self addChild:child];
        }
    }
    return self;
}

- (instancetype)initWithStyle:(OTStretchStyle *)style measure:(OTStretchMeasure)measure {
    self = [self initWithStyle:style children:@[]];
    if (self) {
        self.measureBlock = [measure copy];
        [[OTStretch shared] setMeasure:self.measureBlock forNode:_rustptr context:self.measureBlock];
    }
    return self;
}

- (void)dealloc {
    if (_rustptr) {
        [[OTStretch shared] freeNode:_rustptr];
        _rustptr = NULL;
    }
}

- (NSArray<OTStretchNode *> *)children {
    return [_mutableChildren copy];
}

- (void)setStyle:(OTStretchStyle *)style {
    _style = style;
    [[OTStretch shared] setStyle:style.rustptr forNode:_rustptr];
}

- (void)addChild:(OTStretchNode *)child {
    [[OTStretch shared] addChild:child.rustptr toNode:_rustptr];
    [_mutableChildren addObject:child];
}

- (void)markDirty {
    [[OTStretch shared] markDirty:_rustptr];
}

- (OTStretchLayout *)computeLayoutWidth:(float)width height:(float)height {
    id layout = [[OTStretch shared] computeLayoutForNode:_rustptr width:width height:height];
    return layout;
}

@end

@implementation OTStretch {
    void *_stretchptr;
    dispatch_semaphore_t _semaphore;
    NSMutableArray *_retainedMeasures;
}

+ (instancetype)shared {
    static OTStretch *stretch = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        stretch = [[OTStretch alloc] init];
    });
    return stretch;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _semaphore = dispatch_semaphore_create(1);
        _stretchptr = stretch_init();
        _retainedMeasures = [NSMutableArray array];
    }
    return self;
}

- (void *)createNodeWithStyle:(void *)style {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    void *node = stretch_node_create(_stretchptr, style);
    dispatch_semaphore_signal(_semaphore);
    return node;
}

- (void)freeNode:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_free(_stretchptr, node);
    dispatch_semaphore_signal(_semaphore);
}

- (void)setStyle:(void *)style forNode:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_set_style(_stretchptr, node, style);
    dispatch_semaphore_signal(_semaphore);
}

- (void)markDirty:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_mark_dirty(_stretchptr, node);
    dispatch_semaphore_signal(_semaphore);
}

- (BOOL)isDirty:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    BOOL dirty = stretch_node_dirty(_stretchptr, node);
    dispatch_semaphore_signal(_semaphore);
    return dirty;
}

- (void)addChild:(void *)child toNode:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_add_child(_stretchptr, node, child);
    dispatch_semaphore_signal(_semaphore);
}

- (void)removeChild:(void *)child fromNode:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_remove_child(_stretchptr, node, child);
    dispatch_semaphore_signal(_semaphore);
}

- (void)removeChildAtIndex:(NSUInteger)index fromNode:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_remove_child_at_index(_stretchptr, node, (uintptr_t)index);
    dispatch_semaphore_signal(_semaphore);
}

- (void)replaceChild:(void *)child atIndex:(NSUInteger)index forNode:(void *)node {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    stretch_node_replace_child_at_index(_stretchptr, node, (uintptr_t)index, child);
    dispatch_semaphore_signal(_semaphore);
}

- (void)setMeasure:(StretchSize (^)(float, float))measure forNode:(void *)node context:(id)context {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [_retainedMeasures addObject:context];
    stretch_node_set_measure(_stretchptr, node, (__bridge void *)context, OTMeasureThunk);
    (void)measure;
    dispatch_semaphore_signal(_semaphore);
}

- (id)computeLayoutForNode:(void *)node width:(float)width height:(float)height {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    void *raw = stretch_node_compute_layout(_stretchptr, node, width, height, OTCreateLayout);
    dispatch_semaphore_signal(_semaphore);
    if (raw == NULL) {
        return nil;
    }
    return (__bridge_transfer id)raw;
}

@end
