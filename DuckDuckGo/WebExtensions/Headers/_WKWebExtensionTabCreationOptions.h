#import <Foundation/Foundation.h>

@protocol _WKWebExtensionTab;
@protocol _WKWebExtensionWindow;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.2), ios(17.2))
@interface _WKWebExtensionTabCreationOptions : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, nullable, readonly, strong) id <_WKWebExtensionWindow> desiredWindow;

@property (nonatomic, readonly) NSUInteger desiredIndex;

@property (nonatomic, nullable, readonly, strong) id <_WKWebExtensionTab> desiredParentTab;

@property (nonatomic, nullable, readonly, copy) NSURL *desiredURL;

@property (nonatomic, readonly) BOOL shouldActivate;

@property (nonatomic, readonly) BOOL shouldSelect;

@property (nonatomic, readonly) BOOL shouldPin;

@property (nonatomic, readonly) BOOL shouldMute;

@property (nonatomic, readonly) BOOL shouldShowReaderMode;

@end

NS_ASSUME_NONNULL_END
