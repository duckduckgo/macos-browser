//
//  EncryptedStringTransformer.swift
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

class EncryptedValueTransformer<T: NSCoding & NSObject>: ValueTransformer {

    private let keyStore: EncryptionKeyStoring

    init(keyStore: EncryptionKeyStoring = EncryptionKeyStore()) {
        self.keyStore = keyStore
    }

    public override class func transformedValueClass() -> AnyClass {
        T.self
    }

    public override class func allowsReverseTransformation() -> Bool {
        true
    }

    public override func transformedValue(_ value: Any?) -> Any? {
        let generator = EncryptionKeyGenerator()
        let keyStore = EncryptionKeyStore(generator: generator)

        guard let value = value as? T,
              let key = try? keyStore.readKey(),
              let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) else { return nil }

        return try? DataEncryption.encrypt(data: archivedData, key: key)
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        let generator = EncryptionKeyGenerator()
        let keyStore = EncryptionKeyStore(generator: generator)

        guard let data = value as? Data,
              let key = try? keyStore.readKey(),
              let decryptedData = try? DataEncryption.decrypt(data: data, key: key) else { return nil }

        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: decryptedData as Data)
    }

    public static var transformerName: NSValueTransformerName {
        let className = String(describing: T.self)
        return NSValueTransformerName("\(className)Transformer")
    }

    public static func registerTransformer() {
        let transformer = EncryptedValueTransformer<T>()
        ValueTransformer.setValueTransformer(transformer, forName: transformerName)
    }

}
