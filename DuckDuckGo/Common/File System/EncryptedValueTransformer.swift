//
//  EncryptedValueTransformer.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CryptoKit
import os.log

final class EncryptedValueTransformer<T: NSSecureCoding & NSObject>: ValueTransformer {

    private let encryptionKey: SymmetricKey

    init(encryptionKey: SymmetricKey) {
        os_log("DEBUG: Value transformer for type '%{public}s' created with encryption key of size %{public}d", type: .error, String(describing: T.self), encryptionKey.bitCount)
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
                os_log("DEBUG: Error! Failed to transform value, with error: %{public}s", type: .error, error.localizedDescription)

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

        if let unarchivedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: decryptedData as Data) {
            os_log("VALUETRANSFORMER: Value transformer for %{public}s successfully reverse transformed data of length %{public}d", type: .error, String(describing: T.self), decryptedData.count)
            return unarchivedObject
        }
        
        os_log("DEBUG: Value transformer for %{public}s failed to reverse transform data", type: .error, String(describing: T.self))
        
        return nil
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
        
        os_log("DEBUG: Value transformer registered for type '%{public}s'", type: .error, String(describing: T.self))
    }

}
