//
//  ChromiumKeychainPrompt.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import PixelKit

enum ChromiumKeychainPromptResult {
    case password(String)
    case failedToDecodePasswordData
    case userDeniedKeychainPrompt
    case keychainError(OSStatus)
}

protocol ChromiumKeychainPrompting {

    func promptForChromiumPasswordKeychainAccess(processName: String) -> ChromiumKeychainPromptResult

}

final class ChromiumKeychainPrompt: ChromiumKeychainPrompting {

    func promptForChromiumPasswordKeychainAccess(processName: String) -> ChromiumKeychainPromptResult {
        let key = "\(processName) Safe Storage"

        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrLabel as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne] as [String: Any]

        var dataFromKeychain: AnyObject?

        // Fire Pixel to help measure rate of password prompt denied actions
        PixelKit.fire(GeneralPixel.passwordImportKeychainPrompt)

        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataFromKeychain)

        if status == noErr, let passwordData = dataFromKeychain as? Data {
            if let password = String(data: passwordData, encoding: .utf8) {
                return .password(password)
            } else {
                return .failedToDecodePasswordData
            }
        } else if status == errSecUserCanceled {
            return .userDeniedKeychainPrompt
        } else {
            return .keychainError(status)
        }
    }

}
