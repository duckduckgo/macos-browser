//
//  Database.swift
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

import AppKit
import BrowserServicesKit
import CoreData
import Foundation
import Persistence
import PixelKit

final class Database {

    fileprivate struct Constants {
        static let databaseName = "Database"
    }

    static let shared: CoreDataDatabase = {
        let (database, error) = makeDatabase()
        if database == nil {
            firePixelErrorIfNeeded(error: error)
            NSAlert.databaseFactoryFailed().runModal()
            NSApp.terminate(nil)
        }

        return database!
    }()

    static func makeDatabase() -> (CoreDataDatabase?, Error?) {
        func makeDatabase(keyStore: EncryptionKeyStoring, containerLocation: URL) -> (CoreDataDatabase?, Error?) {

            let mainModel = NSManagedObjectModel.mergedModel(from: [.main])!

            _=mainModel.registerValueTransformers(withAllowedPropertyClasses: [
                NSImage.self,
                NSString.self,
                NSURL.self,
                NSNumber.self,
                NSError.self,
                NSData.self
            ], keyStore: keyStore)

            let httpsUpgradeModel = HTTPSUpgrade.managedObjectModel

            return (CoreDataDatabase(name: Constants.databaseName,
                                     containerLocation: containerLocation,
                                     model: .init(byMerging: [mainModel, httpsUpgradeModel])!), nil)
        }
#if DEBUG
        assert(![.unitTests, .xcPreviews].contains(NSApp.runType), {
            "Use CoreData.---Container() methods for testing purposes:\n" + Thread.callStackSymbols.description
        }())
#endif

        let keyStore: EncryptionKeyStoring = {
#if DEBUG
            guard case .normal = NSApp.runType else {
                return (NSClassFromString("MockEncryptionKeyStore") as? EncryptionKeyStoring.Type)!.init()
            }
#endif
            return EncryptionKeyStore(generator: EncryptionKeyGenerator())
        }()

        let containerLocation: URL = {
#if DEBUG
            guard case .normal = NSApp.runType else {
                return FileManager.default.temporaryDirectory
            }
#endif
            return .sandboxApplicationSupportURL
        }()

        return makeDatabase(keyStore: keyStore, containerLocation: containerLocation)
    }

    // MARK: - Pixel

    @UserDefaultsWrapper(key: .lastDatabaseFactoryFailurePixelDate, defaultValue: nil)
    static var lastDatabaseFactoryFailurePixelDate: Date?

    static func firePixelErrorIfNeeded(error: Error?) {
        let lastPixelSentAt = lastDatabaseFactoryFailurePixelDate ?? Date.distantPast

        // Fire the pixel once a day at max
        if lastPixelSentAt < Date.daysAgo(1) {
            lastDatabaseFactoryFailurePixelDate = Date()
            PixelKit.fire(DebugEvent(GeneralPixel.dbMakeDatabaseError(error: error)))
        }
    }
}

extension Array where Element == CoreDataErrorsParser.ErrorInfo {

    var errorPixelParameters: [String: String] {
        let params: [String: String]
        if let first = first {
            params = ["errorCount": "\(count)",
                      "coreDataCode": "\(first.code)",
                      "coreDataDomain": first.domain,
                      "coreDataEntity": first.entity ?? "empty",
                      "coreDataAttribute": first.property ?? "empty"]
        } else {
            params = ["errorCount": "\(count)"]
        }
        return params
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

extension NSManagedObjectModel {

    private static let transformerUserInfoKey = "transformer"
    func registerValueTransformers(withAllowedPropertyClasses allowedPropertyClasses: [AnyClass]? = nil,
                                   keyStore: EncryptionKeyStoring) -> [NSValueTransformerName] {
        var registeredTransformers = [NSValueTransformerName]()
        let allowedPropertyClassNames = allowedPropertyClasses.map { Set($0.map(NSStringFromClass)) }

        // fix "no NSValueTransformer with class name 'X'" warnings
        // https://stackoverflow.com/a/77623593/748453
        for entity in self.entities {
            for property in entity.properties {
                guard let property = property as? NSAttributeDescription, property.attributeType == .transformableAttributeType else { continue }

                let transformerName: String
                if let valueTransformerName = property.valueTransformerName, !valueTransformerName.isEmpty {
                    transformerName = valueTransformerName
                } else if let transformerUserInfoValue = property.userInfo?[Self.transformerUserInfoKey] as? String, !transformerUserInfoValue.isEmpty {
                    transformerName = transformerUserInfoValue
                    property.userInfo?.removeValue(forKey: Self.transformerUserInfoKey)
                    property.valueTransformerName = transformerName
                } else {
                    assertionFailure("Transformer (User Info `transformer` key) not set for \(entity).\(property)")
                    continue
                }

                guard ValueTransformer(forName: .init(rawValue: transformerName)) == nil else { continue }

                let propertyClassName = transformerName.dropping(suffix: "Transformer")
                assert(propertyClassName != transformerName, "Expected Transformer name like `NSStringTransformer`")
                guard allowedPropertyClassNames?.contains(propertyClassName) != false,
                      let propertyClass = NSClassFromString(propertyClassName) else {
                    assertionFailure("Invalid class name `\(propertyClassName)` for \(transformerName)")
                    continue
                }

                let transformer = ValueTransformer.registerValueTransformer(for: propertyClass, with: keyStore)
                assert(ValueTransformer(forName: .init(transformerName)) != nil)
                registeredTransformers.append(transformer)
            }
        }
        return registeredTransformers
    }

}

extension NSManagedObjectContext {

    func save(onErrorFire event: PixelKitEventV2) throws {
        do {
            try save()
        } catch {
            let nsError = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: nsError)

            PixelKit.fire(DebugEvent(event, error: error),
                       withAdditionalParameters: processedErrors.errorPixelParameters)

            throw error
        }
    }
}
