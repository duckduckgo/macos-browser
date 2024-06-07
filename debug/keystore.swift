#!/usr/bin/env swift

import Foundation
import CryptoKit

protocol EncryptionKeyGenerating {
    func randomKey() -> SymmetricKey
}

final class EncryptionKeyGenerator: EncryptionKeyGenerating {

    func randomKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

}

protocol EncryptionKeyStoring {
    init()

    func store(key: SymmetricKey) throws
    func readKey() throws -> SymmetricKey
    func deleteKey() throws
}

extension ContiguousBytes {

    var dataRepresentation: Data {
        return self.withUnsafeBytes { bytes in
            let data = CFDataCreateWithBytesNoCopy(nil, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), bytes.count, kCFAllocatorNull)
            return ((data as NSData?) as Data?) ?? Data()
        }
    }

}

enum EncryptionKeyStoreError: Error {
    case storageFailed(OSStatus)
    case readFailed(OSStatus)
    case deletionFailed(OSStatus)
    case cannotTransformDataToString(OSStatus)
    case cannotTransfrotmStringToBase64Data(OSStatus)
}

final class EncryptionKeyStore: EncryptionKeyStoring {

    enum Constants {
        static let encryptionKeyAccount = "com.duckduckgo.macos.browser"
        static let encryptionKeyService = "DuckDuckGo Privacy Browser Data Encryption Key"
        static let encryptionKeyServiceBase64 = "DuckDuckGo Privacy Browser Encryption Key v2"
    }

    private let generator: EncryptionKeyGenerating
    private let account: String

    private var defaultKeychainQueryAttributes: [String: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account
        ] as [String: Any]
    }

    init(generator: EncryptionKeyGenerating, account: String = Constants.encryptionKeyAccount) {
        self.generator = generator
        self.account = account
    }

    convenience init() {
        self.init(generator: EncryptionKeyGenerator())
    }

    // MARK: - Keychain

    func store(key: SymmetricKey) throws {
         let attributes: [String: Any] = [
             kSecClass as String: kSecClassGenericPassword,
             kSecAttrAccount as String: account,
             kSecValueData as String: key.dataRepresentation.base64EncodedString(),
             kSecAttrService as String: Constants.encryptionKeyServiceBase64,
             kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
         ]

         // Add the login item to the keychain
         let status = SecItemAdd(attributes as CFDictionary, nil)

         guard status == errSecSuccess else {
             throw EncryptionKeyStoreError.storageFailed(status)
         }
     }

    func readKey() throws -> SymmetricKey {
        /// Needed to change how we save the key
        /// Checks if the base64 non iCloud key already exist
        /// if so we return
        if let key = try? readKeyFromKeychain(account: account, format: .base64) {
            return key
        }
        /// If the base64 key does not exist we check if we have the legacy key
        /// if so we store it as base64 local item key
        if let key = try readKeyFromKeychain(account: account, format: .raw) {
            try store(key: key)
        }

        /// We try again to retrieve the base64 non iCloud key
        /// if so we return the key
        /// otherwise we generate a new one and store it
        if let key = try readKeyFromKeychain(account: account, format: .base64) {
            return key
        } else {
            let generatedKey = generator.randomKey()
            try store(key: generatedKey)
            return generatedKey
        }
    }

    func deleteKey() throws {
        let status = SecItemDelete(defaultKeychainQueryAttributes as CFDictionary)

        switch status {
        case errSecItemNotFound, errSecSuccess: break
        default:
            throw EncryptionKeyStoreError.deletionFailed(status)
        }
    }

    // MARK: - Private

    private enum KeyFormat {
        case raw
        case base64
    }

    private func readKeyFromKeychain(account: String, format: KeyFormat) throws -> SymmetricKey? {
        var query = defaultKeychainQueryAttributes
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        switch format {
        case .raw:
            query[kSecAttrService as String] = Constants.encryptionKeyService
        case .base64:
            query[kSecAttrService as String] = Constants.encryptionKeyServiceBase64
        }
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw EncryptionKeyStoreError.readFailed(status)
            }

            let finalData: Data
            switch format {
            case .raw:
                finalData = data
            case .base64:
                guard let base64String = String(data: data, encoding: .utf8) else {
                    throw EncryptionKeyStoreError.cannotTransformDataToString(status)
                }
                guard let keyData = Data(base64Encoded: base64String) else {
                    throw EncryptionKeyStoreError.cannotTransfrotmStringToBase64Data(status)
                }
                finalData = keyData
            }
            return SymmetricKey(data: finalData)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionKeyStoreError.readFailed(status)
        }
    }
}

final class EncryptedValueTransformer<T: NSSecureCoding & NSObject>: ValueTransformer {

    private let encryptionKey: SymmetricKey

    init(encryptionKey: SymmetricKey) {
        self.encryptionKey = encryptionKey
    }

    override class func transformedValueClass() -> AnyClass {
        T.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let castValue = value as? T else {
            assertionFailure("\(String(describing: value)) could not be converted to \(T.self)")
            return nil
        }
        let archivedData: Data
        // if T is Data
        if let data = castValue as? Data {
            archivedData = data
        } else {
            do {
                archivedData = try NSKeyedArchiver.archivedData(withRootObject: castValue, requiringSecureCoding: true)
            } catch {
                assertionFailure("Could not archive value \(castValue): \(error)")
                return nil
            }
        }

        return try? DataEncryption.encrypt(data: archivedData, key: encryptionKey)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data,
              let decryptedData = try? DataEncryption.decrypt(data: data, key: encryptionKey) else { return nil }

        // if T is Data
        if let data = decryptedData as? T {
            return data
        }

        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: decryptedData as Data)
    }

    // The transformer name is calculated based on the generic class parameter.
    // For instance, EncryptedValueTransformer<String> would be named "StringTransformer", and should be specified as such in Core Data attributes.
    static var transformerName: NSValueTransformerName {
        let className = String(describing: T.self)
        return NSValueTransformerName("\(className)Transformer")
    }

    static func registerTransformer(keyStore: EncryptionKeyStoring) throws {
        let key = try keyStore.readKey()
        let transformer = EncryptedValueTransformer<T>(encryptionKey: key)

        ValueTransformer.setValueTransformer(transformer, forName: transformerName)
    }

}

enum DataEncryptionError: Error {
    case invalidData
    case decryptionFailed
}

final class DataEncryption {

    static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        try ChaChaPoly.seal(data, using: key).combined
    }

    static func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: data)
            return try ChaChaPoly.open(sealedBox, using: key)
        } catch {
            switch error {
            // This error is thrown when the sealed box cannot be created, i.e. the data has changed for some reason and can no longer be decrypted.
            case CryptoKitError.incorrectParameterSize:
                throw DataEncryptionError.invalidData
            default:
                throw DataEncryptionError.decryptionFailed
            }
        }
    }

}

extension ValueTransformer {

    static func registerValueTransformer(for propertyClass: AnyClass, with keyStore: EncryptionKeyStoring) -> NSValueTransformerName {
        guard let encodableType = propertyClass as? (NSObject & NSSecureCoding).Type else {
            fatalError("Unsupported type")
        }
        func registerValueTransformer<T: NSObject & NSSecureCoding>(for type: T.Type) -> NSValueTransformerName {
            (try? EncryptedValueTransformer<T>.registerTransformer(keyStore: keyStore))!
            return EncryptedValueTransformer<T>.transformerName
        }
        return registerValueTransformer(for: encodableType)
    }

}

extension String {

    func dropping(suffix: String) -> String {
        return hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }

}

func registerValueTransformers(withAllowedPropertyClasses allowedPropertyClasses: [AnyClass],
                               keyStore: EncryptionKeyStoring) -> [NSValueTransformerName] {
    var registeredTransformers = [NSValueTransformerName]()

    for propertyClass in allowedPropertyClasses {
        let propertyClassName = NSStringFromClass(propertyClass)
        let transformer = ValueTransformer.registerValueTransformer(for: propertyClass, with: keyStore)
        assert(ValueTransformer(forName: .init(propertyClassName + "Transformer")) != nil)
        registeredTransformers.append(transformer)
    }

    return registeredTransformers
}

var registeredTransformers = [NSValueTransformerName]()

