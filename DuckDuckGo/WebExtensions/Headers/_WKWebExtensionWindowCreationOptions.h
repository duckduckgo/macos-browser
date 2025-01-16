#import <Foundation/Foundation.h>

#import "_WKWebExtensionWindow.h"

@protocol _WKWebExtensionTab;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.2), ios(17.2))
@interface _WKWebExtensionWindowCreationOptions : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) _WKWebExtensionWindowType desiredWindowType;

@property (nonatomic, readonly) _WKWebExtensionWindowState desiredWindowState;

@property (nonatomic, readonly) CGRect desiredFrame;

@property (nonatomic, readonly, copy) NSArray<NSURL *> *desiredURLs;

@property (nonatomic, readonly, copy) NSArray<id <_WKWebExtensionTab>> *desiredTabs;

@property (nonatomic, readonly) BOOL shouldFocus;

@property (nonatomic, readonly) BOOL shouldUsePrivateBrowsing;

@end

NS_ASSUME_NONNULL_END
