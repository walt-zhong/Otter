#import "OTStretchLayout.h"

@implementation OTStretchLayout

- (instancetype)initWithX:(float)x
                        y:(float)y
                    width:(float)width
                   height:(float)height
                 children:(NSArray<OTStretchLayout *> *)children {
    self = [super init];
    if (self) {
        _x = x;
        _y = y;
        _width = width;
        _height = height;
        _children = children;
    }
    return self;
}

+ (instancetype)fromFloats:(const float *)floats consumed:(const float **)consumed {
    const float *cursor = floats;
    float x = cursor[0];
    float y = cursor[1];
    float width = cursor[2];
    float height = cursor[3];
    int childCount = (int)cursor[4];
    cursor += 5;
    NSMutableArray<OTStretchLayout *> *children = [NSMutableArray arrayWithCapacity:(NSUInteger)MAX(childCount, 0)];
    for (int index = 0; index < childCount; index++) {
        const float *next = cursor;
        OTStretchLayout *child = [OTStretchLayout fromFloats:cursor consumed:&next];
        cursor = next;
        [children addObject:child];
    }
    if (consumed) {
        *consumed = cursor;
    }
    return [[OTStretchLayout alloc] initWithX:x y:y width:width height:height children:children];
}

@end
