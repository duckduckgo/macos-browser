#import <Foundation/Foundation.h>

#import "_WKWebExtensionControllerDelegate.h"
#import "_WKWebExtensionDataType.h"
#import "_WKWebExtensionTab.h"
#import "_WKWebExtensionWindow.h"

@class _WKWebExtension;
@class _WKWebExtensionContext;
@class _WKWebExtensionControllerConfiguration;
@class _WKWebExtensionDataRecord;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.4), ios(16.4))
@interface _WKWebExtensionController : NSObject

- (instancetype)init NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithConfiguration:(_WKWebExtensionControllerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@property (nonatomic, weak) id <_WKWebExtensionControllerDelegate> delegate;

@property (nonatomic, readonly, copy) _WKWebExtensionControllerConfiguration *configuration;

- (BOOL)loadExtensionContext:(_WKWebExtensionContext *)extensionContext error:(NSError **)error;

- (BOOL)unloadExtensionContext:(_WKWebExtensionContext *)extensionContext error:(NSError **)error;

- (nullable _WKWebExtensionContext *)extensionContextForExtension:(_WKWebExtension *)extension NS_SWIFT_NAME(extensionContext(for:));

- (nullable _WKWebExtensionContext *)extensionContextForURL:(NSURL *)URL NS_SWIFT_NAME(extensionContext(for:));

@property (nonatomic, readonly, copy) NSSet<_WKWebExtension *> *extensions;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionContext *> *extensionContexts;

@property (class, nonatomic, readonly, copy) NSSet<_WKWebExtensionDataType> *allExtensionDataTypes;

- (void)fetchDataRecordsOfTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes completionHandler:(void (^)(NSArray<_WKWebExtensionDataRecord *> *))completionHandler WK_SWIFT_ASYNC_NAME(dataRecords(ofTypes:));

- (void)fetchDataRecordOfTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(_WKWebExtensionDataRecord * _Nullable))completionHandler WK_SWIFT_ASYNC_NAME(dataRecord(ofTypes:for:));

- (void)removeDataOfTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes forDataRecords:(NSArray<_WKWebExtensionDataRecord *> *)dataRecords completionHandler:(void (^)(void))completionHandler;

- (void)didOpenWindow:(id <_WKWebExtensionWindow>)newWindow;

- (void)didCloseWindow:(id <_WKWebExtensionWindow>)closedWindow;

- (void)didFocusWindow:(nullable id <_WKWebExtensionWindow>)focusedWindow;

- (void)didOpenTab:(id <_WKWebExtensionTab>)newTab;

- (void)didCloseTab:(id <_WKWebExtensionTab>)closedTab windowIsClosing:(BOOL)windowIsClosing;

- (void)didActivateTab:(id<_WKWebExtensionTab>)activatedTab previousActiveTab:(nullable id<_WKWebExtensionTab>)previousTab;

- (void)didSelectTabs:(NSSet<id <_WKWebExtensionTab>> *)selectedTabs;

- (void)didDeselectTabs:(NSSet<id <_WKWebExtensionTab>> *)deselectedTabs;

- (void)didMoveTab:(id <_WKWebExtensionTab>)movedTab fromIndex:(NSUInteger)index inWindow:(nullable id <_WKWebExtensionWindow>)oldWindow NS_SWIFT_NAME(didMoveTab(_:from:in:));

- (void)didReplaceTab:(id <_WKWebExtensionTab>)oldTab withTab:(id <_WKWebExtensionTab>)newTab NS_SWIFT_NAME(didReplaceTab(_:with:));

- (void)didChangeTabProperties:(_WKWebExtensionTabChangedProperties)properties forTab:(id <_WKWebExtensionTab>)changedTab NS_SWIFT_NAME(didChangeTabProperties(_:for:));

@end

NS_ASSUME_NONNULL_END
