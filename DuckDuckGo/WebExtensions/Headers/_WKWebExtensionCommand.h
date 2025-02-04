#import <Foundation/Foundation.h>

@class _WKWebExtensionContext;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.4), ios(17.4), visionos(1.1))
@interface _WKWebExtensionCommand : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly, weak) _WKWebExtensionContext *webExtensionContext;

@property (nonatomic, readonly, copy) NSString *identifier;

@property (nonatomic, readonly, copy) NSString *discoverabilityTitle;

@property (nonatomic, nullable, copy) NSString *activationKey;

@property (nonatomic) NSEventModifierFlags modifierFlags;

@property (nonatomic, readonly, copy) NSMenuItem *menuItem;

@end

NS_ASSUME_NONNULL_END
