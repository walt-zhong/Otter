#import <Foundation/Foundation.h>
#import "PermissionResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface PermissionJudge : NSObject
+ (PermissionResult *)single:(NSString *)capability
                      granted:(BOOL)granted
                        asked:(BOOL)asked
          shouldShowRationale:(BOOL)shouldShowRationale;
+ (PermissionResult *)locationWithFineGranted:(BOOL)fineGranted
                                coarseGranted:(BOOL)coarseGranted
                                        asked:(BOOL)asked
                               fineShouldShow:(BOOL)fineShouldShow
                             coarseShouldShow:(BOOL)coarseShouldShow;
+ (PermissionResult *)notificationsWithRequiresRuntime:(BOOL)requiresRuntime
                                               granted:(BOOL)granted
                                                 asked:(BOOL)asked
                                   shouldShowRationale:(BOOL)shouldShowRationale;
+ (PermissionResult *)photosAsked:(BOOL)asked;
+ (PermissionResult *)grantedPhoto:(NSString *)uri;
+ (PermissionResult *)unsupported:(NSString *)capability;
@end

NS_ASSUME_NONNULL_END
