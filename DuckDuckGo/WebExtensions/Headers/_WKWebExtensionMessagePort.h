#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

WK_EXTERN NSErrorDomain const _WKWebExtensionMessagePortErrorDomain API_AVAILABLE(macos(14.4), ios(17.4), visionos(1.1));

typedef NS_ERROR_ENUM(_WKWebExtensionMessagePortErrorDomain, _WKWebExtensionMessagePortError) {
    _WKWebExtensionMessagePortErrorUnknown,
    _WKWebExtensionMessagePortErrorNotConnected,
    _WKWebExtensionMessagePortErrorMessageInvalid,
} NS_SWIFT_NAME(_WKWebExtensionMessagePort.Error) API_AVAILABLE(macos(14.4), ios(17.4), visionos(1.1));

API_AVAILABLE(macos(14.4), ios(17.4), visionos(1.1))
NS_SWIFT_NAME(_WKWebExtension.MessagePort)
@interface _WKWebExtensionMessagePort : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly, nullable) NSString *applicationIdentifier;

@property (nonatomic, copy, nullable) void (^messageHandler)(id _Nullable message, NSError * _Nullable error);

@property (nonatomic, copy, nullable) void (^disconnectHandler)(NSError * _Nullable error);

@property (nonatomic, readonly, getter=isDisconnected) BOOL disconnected;

- (void)sendMessage:(nullable id)message completionHandler:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completionHandler WK_SWIFT_ASYNC_THROWS_ON_FALSE(1);

- (void)disconnectWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
