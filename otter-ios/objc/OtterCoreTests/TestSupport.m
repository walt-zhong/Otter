#import "TestSupport.h"

BOOL OTIsDirectory(NSString *path) {
    BOOL isDirectory = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory;
}

BOOL OTIsFile(NSString *path) {
    BOOL isDirectory = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory;
}

static NSURL *OTRepoRoot(void) {
    NSString *path = [NSString stringWithUTF8String:__FILE__];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSInteger index = 0; index < 8; index++) {
        url = url.URLByDeletingLastPathComponent;
        NSString *marker = [url.path stringByAppendingPathComponent:@"OtterDemo.xcodeproj"];
        if (OTIsDirectory(marker)) {
            return url;
        }
    }
    return url;
}

NSURL *OTFirstExistingDirectory(NSArray<NSString *> *relatives) {
    NSURL *cwd = [NSURL fileURLWithPath:NSFileManager.defaultManager.currentDirectoryPath];
    NSURL *root = OTRepoRoot();
    NSArray<NSURL *> *bases = @[cwd, root];
    for (NSString *relative in relatives) {
        for (NSURL *base in bases) {
            NSURL *candidate = [base URLByAppendingPathComponent:relative].URLByStandardizingPath;
            if (OTIsDirectory(candidate.path)) {
                return candidate;
            }
        }
    }
    return nil;
}
