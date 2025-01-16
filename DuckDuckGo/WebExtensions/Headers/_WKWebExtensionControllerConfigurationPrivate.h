#import "_WKWebExtensionControllerConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface _WKWebExtensionControllerConfiguration ()

+ (instancetype)_temporaryConfiguration;

@property (nonatomic, readonly, getter=_isTemporary) BOOL _temporary;

@property (nonatomic, nullable, copy, setter=_setStorageDirectoryPath:) NSString *_storageDirectoryPath;

@end

NS_ASSUME_NONNULL_END
