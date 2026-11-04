#import "PermissionJudge.h"
#import "PermissionCapability.h"

@implementation PermissionJudge

+ (PermissionResult *)single:(NSString *)capability
                      granted:(BOOL)granted
                        asked:(BOOL)asked
          shouldShowRationale:(BOOL)shouldShowRationale {
    if (granted) {
        return [[PermissionResult alloc] initWithCapability:capability
                                                      status:[PermissionStatus GRANTED]
                                                 canAskAgain:NO
                                                       asked:asked
                                                      detail:nil];
    }
    if (!asked || shouldShowRationale) {
        return [[PermissionResult alloc] initWithCapability:capability
                                                      status:[PermissionStatus DENIED]
                                                 canAskAgain:YES
                                                       asked:asked
                                                      detail:nil];
    }
    return [[PermissionResult alloc] initWithCapability:capability
                                                  status:[PermissionStatus PERMANENTLY_DENIED]
                                             canAskAgain:NO
                                                   asked:YES
                                                  detail:nil];
}

+ (PermissionResult *)locationWithFineGranted:(BOOL)fineGranted
                                coarseGranted:(BOOL)coarseGranted
                                        asked:(BOOL)asked
                               fineShouldShow:(BOOL)fineShouldShow
                             coarseShouldShow:(BOOL)coarseShouldShow {
    if (fineGranted) {
        return [[PermissionResult alloc] initWithCapability:[PermissionCapability LOCATION_WHEN_IN_USE]
                                                      status:[PermissionStatus GRANTED]
                                                 canAskAgain:NO
                                                       asked:asked
                                                      detail:@"precise"];
    }
    if (coarseGranted) {
        BOOL canUpgrade = !asked || fineShouldShow;
        return [[PermissionResult alloc] initWithCapability:[PermissionCapability LOCATION_WHEN_IN_USE]
                                                      status:[PermissionStatus LIMITED]
                                                 canAskAgain:canUpgrade
                                                       asked:asked
                                                      detail:@"approximate"];
    }
    return [self single:[PermissionCapability LOCATION_WHEN_IN_USE]
                 granted:NO
                   asked:asked
     shouldShowRationale:fineShouldShow || coarseShouldShow];
}

+ (PermissionResult *)notificationsWithRequiresRuntime:(BOOL)requiresRuntime
                                               granted:(BOOL)granted
                                                 asked:(BOOL)asked
                                   shouldShowRationale:(BOOL)shouldShowRationale {
    if (!requiresRuntime) {
        return [[PermissionResult alloc] initWithCapability:[PermissionCapability NOTIFICATIONS]
                                                      status:[PermissionStatus GRANTED]
                                                 canAskAgain:NO
                                                       asked:NO
                                                      detail:nil];
    }
    return [self single:[PermissionCapability NOTIFICATIONS]
                 granted:granted
                   asked:asked
     shouldShowRationale:shouldShowRationale];
}

+ (PermissionResult *)photosAsked:(BOOL)asked {
    return [[PermissionResult alloc] initWithCapability:[PermissionCapability PHOTOS]
                                                  status:[PermissionStatus DENIED]
                                             canAskAgain:YES
                                                   asked:asked
                                                  detail:nil];
}

+ (PermissionResult *)grantedPhoto:(NSString *)uri {
    return [[PermissionResult alloc] initWithCapability:[PermissionCapability PHOTOS]
                                                  status:[PermissionStatus GRANTED]
                                             canAskAgain:YES
                                                   asked:YES
                                                  detail:uri];
}

+ (PermissionResult *)unsupported:(NSString *)capability {
    return [[PermissionResult alloc] initWithCapability:capability
                                                  status:[PermissionStatus UNSUPPORTED]
                                             canAskAgain:NO
                                                   asked:NO
                                                  detail:nil];
}

@end
