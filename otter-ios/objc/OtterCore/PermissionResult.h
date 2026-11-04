#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PermissionResult : NSObject
@property (nonatomic, copy, readonly) NSString *capability;
@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, readonly) BOOL canAskAgain;
@property (nonatomic, readonly) BOOL asked;
@property (nonatomic, copy, readonly) NSString *detail;
@property (nonatomic, readonly) BOOL showSettings;
- (instancetype)initWithCapability:(NSString *)capability
                            status:(NSString *)status
                       canAskAgain:(BOOL)canAskAgain
                             asked:(BOOL)asked
                            detail:(nullable NSString *)detail;
- (NSString *)statusText;
@end

@interface PermissionPrompt : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *message;
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message;
@end

NS_ASSUME_NONNULL_END
