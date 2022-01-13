//
//  PixelDataRecord.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import CoreData

struct PixelDataRecord {

    let key: String
    let value: NSObject

}

extension PixelData {

    func valueRepresentation() -> PixelDataRecord? {
        guard let key = self.key else {
            assertionFailure("PixelData: Key should not be nil")
            return nil
        }
        guard let data = self.valueEncrypted as? Data else {
            assertionFailure("PixelData: valueEncrypted is not Data")
            return nil
        }
        let unarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSString.self, NSNumber.self], from: data)
        if let string = unarchived as? NSString {
            return PixelDataRecord(key: key, value: string)
        } else if let number = unarchived as? NSNumber {
            return PixelDataRecord(key: key, value: number)
        } else {
            return nil
        }
    }

    func update(with record: PixelDataRecord) throws {
        if self.key != record.key {
            guard self.key == nil else {
                assertionFailure("PixelData: Keys does not match")
                return
            }
            self.key = record.key
        }

        let data = try NSKeyedArchiver.archivedData(withRootObject: record.value, requiringSecureCoding: true)
        self.valueEncrypted = data as NSData
    }

}
