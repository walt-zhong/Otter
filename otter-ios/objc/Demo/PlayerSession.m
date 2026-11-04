#import "PlayerSession.h"
#import "../OtterUI/Engine/ExpansionCenter.h"
#import "../OtterUI/Render/OTNodes.h"

static const long long OTPlayerTick = 500;

static NSString *OTPlayerFormat(long long positionMs) {
    int totalSeconds = (int)(positionMs / 1000);
    return [NSString stringWithFormat:@"%d:%02d", totalSeconds / 60, totalSeconds % 60];
}

static UIView *OTFindTagged(UIView *view, NSString *name) {
    if ([view.accessibilityIdentifier isEqualToString:name] || [[OTViewMark bind:view].idName isEqualToString:name]) {
        return view;
    }
    for (UIView *child in view.subviews) {
        UIView *found = OTFindTagged(child, name);
        if (found) {
            return found;
        }
    }
    return nil;
}

@implementation PlayerSession {
    OTTextView *_playState;
    OTImageView *_cover;
    OTTextView *_title;
    OTTextView *_artist;
    OTTextView *_elapsed;
    OTTextView *_duration;
    OTProgressView *_seek;
    OTImageView *_playToggle;
    OTLottieView *_meter;
    OTListView *_queue;
    NSInteger _index;
    BOOL _playing;
    BOOL _scrubbing;
    long long _positionMs;
    NSTimer *_timer;
    void (^_itemClick)(NSDictionary<NSString *, NSString *> *);
}

+ (instancetype)attach:(UIView *)root {
    OTListView *queue = (OTListView *)OTFindTagged(root, @"queue");
    OTTextView *playState = (OTTextView *)OTFindTagged(root, @"playState");
    OTImageView *cover = (OTImageView *)OTFindTagged(root, @"cover");
    OTTextView *title = (OTTextView *)OTFindTagged(root, @"trackTitle");
    OTTextView *artist = (OTTextView *)OTFindTagged(root, @"trackArtist");
    OTTextView *elapsed = (OTTextView *)OTFindTagged(root, @"elapsed");
    OTTextView *duration = (OTTextView *)OTFindTagged(root, @"duration");
    OTProgressView *seek = (OTProgressView *)OTFindTagged(root, @"seek");
    OTImageView *playToggle = (OTImageView *)OTFindTagged(root, @"playToggle");
    OTLottieView *meter = (OTLottieView *)OTFindTagged(root, @"meter");
    if (![queue isKindOfClass:[OTListView class]] || ![playState isKindOfClass:[OTTextView class]] ||
        ![cover isKindOfClass:[OTImageView class]] || ![title isKindOfClass:[OTTextView class]] ||
        ![artist isKindOfClass:[OTTextView class]] || ![elapsed isKindOfClass:[OTTextView class]] ||
        ![duration isKindOfClass:[OTTextView class]] || ![seek isKindOfClass:[OTProgressView class]] ||
        ![playToggle isKindOfClass:[OTImageView class]] || ![meter isKindOfClass:[OTLottieView class]]) {
        return nil;
    }
    PlayerSession *session = [[PlayerSession alloc] initWithPlayState:playState cover:cover title:title artist:artist elapsed:elapsed duration:duration seek:seek playToggle:playToggle meter:meter queue:queue];
    UIView *prev = OTFindTagged(root, @"playPrev");
    UIView *next = OTFindTagged(root, @"playNext");
    prev.userInteractionEnabled = YES;
    next.userInteractionEnabled = YES;
    playToggle.userInteractionEnabled = YES;
    [session bindTap:prev action:@selector(playPrevious)];
    [session bindTap:next action:@selector(playNext)];
    [session bindTap:playToggle action:@selector(toggle)];
    [session start];
    return session;
}

- (instancetype)initWithPlayState:(OTTextView *)playState cover:(OTImageView *)cover title:(OTTextView *)title artist:(OTTextView *)artist elapsed:(OTTextView *)elapsed duration:(OTTextView *)duration seek:(OTProgressView *)seek playToggle:(OTImageView *)playToggle meter:(OTLottieView *)meter queue:(OTListView *)queue {
    self = [super init];
    if (self) {
        _playState = playState;
        _cover = cover;
        _title = title;
        _artist = artist;
        _elapsed = elapsed;
        _duration = duration;
        _seek = seek;
        _playToggle = playToggle;
        _meter = meter;
        _queue = queue;
        _playing = YES;
    }
    return self;
}

- (void)bindTap:(UIView *)view action:(SEL)action {
    if (!view) {
        return;
    }
    view.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:action];
    [view addGestureRecognizer:tap];
}

- (void)releaseSession {
    [_timer invalidate];
    _timer = nil;
    if (ExpansionCenter.shared.itemClick == _itemClick) {
        ExpansionCenter.shared.itemClick = nil;
    }
    _seek.onSeekChanged = nil;
}

- (void)start {
    _positionMs = (long long)(0.36 * [self durationMs]);
    _seek.seekable = YES;
    __weak PlayerSession *weakSelf = self;
    _seek.onSeekChanged = ^(CGFloat fraction, BOOL settled) {
        PlayerSession *self = weakSelf;
        if (!self) {
            return;
        }
        self->_scrubbing = !settled;
        self->_positionMs = (long long)(fraction * [self durationMs]);
        self->_elapsed.text = OTPlayerFormat(self->_positionMs);
    };
    _itemClick = ^(NSDictionary<NSString *, NSString *> *item) {
        PlayerSession *self = weakSelf;
        NSInteger found = [self indexOf:item];
        if (found >= 0) {
            [self showIndex:found reset:YES];
        }
    };
    ExpansionCenter.shared.itemClick = _itemClick;
    _itemClick = ExpansionCenter.shared.itemClick;
    [self renderClock];
    _timer = [NSTimer timerWithTimeInterval:OTPlayerTick / 1000.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)tick {
    if (_playing && !_scrubbing) {
        _positionMs += OTPlayerTick;
        long long length = [self durationMs];
        if (_positionMs >= length) {
            [self showIndex:_index + 1 reset:YES];
        } else {
            [self renderClock];
        }
    }
}

- (void)toggle {
    _playing = !_playing;
    [self renderTransport];
}

- (void)playPrevious {
    [self showIndex:_index - 1 reset:YES];
}

- (void)playNext {
    [self showIndex:_index + 1 reset:YES];
}

- (void)showIndex:(NSInteger)rawIndex reset:(BOOL)reset {
    NSInteger count = _queue.itemCount;
    if (count == 0) {
        return;
    }
    NSInteger next = rawIndex % count;
    if (next < 0) {
        next += count;
    }
    NSInteger previous = _index;
    _index = next;
    if (reset) {
        _positionMs = 0;
        _playing = YES;
    }
    [_cover load:[_queue itemFieldAtIndex:_index key:@"cover"]];
    _title.text = [_queue itemFieldAtIndex:_index key:@"title"];
    _artist.text = [_queue itemFieldAtIndex:_index key:@"artist"];
    _duration.text = [_queue itemFieldAtIndex:_index key:@"length"];
    [self renderTransport];
    [self renderClock];
    if (previous != _index) {
        [_queue updateItemAtIndex:previous fields:[self idleFields]];
        [_queue updateItemAtIndex:_index fields:[self playingFields]];
        [self revealQueueItem:_index];
    }
}

- (void)revealQueueItem:(NSInteger)index {
    if (index < 0 || index >= _queue.itemCount) {
        return;
    }
    NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewLayoutAttributes *attr = [_queue layoutAttributesForItemAtIndexPath:path];
    if (!attr) {
        return;
    }
    CGFloat top = _queue.contentOffset.y + _queue.adjustedContentInset.top;
    CGFloat visible = _queue.bounds.size.height - _queue.adjustedContentInset.top - _queue.adjustedContentInset.bottom;
    CGFloat bottom = top + visible;
    if (CGRectGetMinY(attr.frame) < top) {
        [_queue scrollToItemAtIndexPath:path atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
    } else if (CGRectGetMaxY(attr.frame) > bottom) {
        [_queue scrollToItemAtIndexPath:path atScrollPosition:UICollectionViewScrollPositionBottom animated:YES];
    }
}

- (void)renderTransport {
    [_playToggle load:_playing ? @"res:ic_player_pause" : @"res:ic_player_play"];
    _playState.text = _playing ? @"正在播放" : @"已暂停";
    [_meter setPlaying:_playing];
}

- (void)renderClock {
    long long length = [self durationMs];
    if (_positionMs > length) {
        _positionMs = length;
    }
    _elapsed.text = OTPlayerFormat(_positionMs);
    [_seek setFraction:length == 0 ? 0 : (CGFloat)_positionMs / (CGFloat)length];
}

- (long long)durationMs {
    NSArray<NSString *> *parts = [[_queue itemFieldAtIndex:_index key:@"length"] componentsSeparatedByString:@":"];
    long long minutes = parts.count > 0 ? parts[0].longLongValue : 0;
    long long seconds = parts.count > 1 ? parts[1].longLongValue : 0;
    long long length = (minutes * 60 + seconds) * 1000;
    return length < 1000 ? 1000 : length;
}

- (NSInteger)indexOf:(NSDictionary<NSString *, NSString *> *)item {
    for (NSInteger i = 0; i < _queue.itemCount; i++) {
        if ([[_queue itemFieldAtIndex:i key:@"title"] isEqualToString:item[@"title"] ?: @""] &&
            [[_queue itemFieldAtIndex:i key:@"artist"] isEqualToString:item[@"artist"] ?: @""] &&
            [[_queue itemFieldAtIndex:i key:@"length"] isEqualToString:item[@"length"] ?: @""]) {
            return i;
        }
    }
    return -1;
}

- (NSDictionary<NSString *, NSString *> *)playingFields {
    return @{@"titleColor": @"#F2C14E", @"rowBg": @"#3A2A22", @"mark": @"正在听"};
}

- (NSDictionary<NSString *, NSString *> *)idleFields {
    return @{@"titleColor": @"#F6F1EA", @"rowBg": @"#241F1C", @"mark": @""};
}

@end
