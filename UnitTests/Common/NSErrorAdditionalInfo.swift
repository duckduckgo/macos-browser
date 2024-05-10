//
//  NSErrorAdditionalInfo.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

extension NSError {

    static let swizzleLocalizedDescriptionOnce: Void = {
        let originalLocalizedDescription = class_getInstanceMethod(NSError.self, #selector(getter: NSError.localizedDescription))!
        let swizzledLocalizedDescription = class_getInstanceMethod(NSError.self, #selector(NSError.swizzledLocalizedDescription))!

        method_exchangeImplementations(originalLocalizedDescription, swizzledLocalizedDescription)
    }()

    // use `NSError.disableSwizzledDescription = true` to return an original localizedDescription, don‘t forget to set it back in tearDown
    @objc dynamic func swizzledLocalizedDescription() -> String {
        if Self.disableSwizzledDescription {
            self.swizzledLocalizedDescription() // return original
        } else {
            self.debugDescription + " – NSErrorAdditionalInfo.swift"
        }
    }

    private static let disableSwizzledDescriptionKey = UnsafeRawPointer(bitPattern: "disableSwizzledDescriptionKey".hashValue)!

    static var disableSwizzledDescription: Bool = false

}
