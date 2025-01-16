#import "_WKWebExtensionDataType.h"

NS_ASSUME_NONNULL_BEGIN

WK_EXTERN NSErrorDomain const _WKWebExtensionDataRecordErrorDomain;

typedef NS_ERROR_ENUM(_WKWebExtensionDataRecordErrorDomain, _WKWebExtensionDataRecordError) {
    _WKWebExtensionDataRecordErrorUnknown,
    _WKWebExtensionDataRecordErrorLocalStorageFailed,
    _WKWebExtensionDataRecordErrorSessionStorageFailed,
    _WKWebExtensionDataRecordErrorSyncStorageFailed,
} NS_SWIFT_NAME(_WKWebExtensionDataRecord.Error);

NS_SWIFT_NAME(_WKWebExtension.DataRecord)
@interface _WKWebExtensionDataRecord : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly, copy) NSString *displayName;

@property (nonatomic, readonly, copy) NSString *uniqueIdentifier;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionDataType> *dataTypes;

@property (nonatomic, readonly) unsigned long long totalSize;

@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;

- (unsigned long long)sizeOfDataTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes;

@end

NS_ASSUME_NONNULL_END
