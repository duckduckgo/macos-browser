//
//  ProcessInfoExtension.swift
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
import ApplicationServices

extension ProcessInfo {
    private typealias GetCurrentProcessType = @convention(c) (UnsafePointer<ProcessSerialNumber>) -> OSStatus
    private typealias CPSSetProcessNameType = @convention(c) (UnsafePointer<ProcessSerialNumber>, UnsafePointer<Int8>) -> OSStatus

    private static let GetCurrentProcess: GetCurrentProcessType? = dynamicSymbol(named: "GetCurrentProcess")
    private static let CPSSetProcessName: CPSSetProcessNameType? = dynamicSymbol(named: "CPSSetProcessName")

    struct OSError: Error {
        let status: OSStatus
    }

    func setProcessName(_ name: String) throws {
        var psn = ProcessSerialNumber()
        var status: OSStatus
        status = Self.GetCurrentProcess?(&psn) ?? -1
        guard status == 0 else { throw OSError(status: status) }
        
        status = name.withCString {
            Self.CPSSetProcessName?(&psn, $0) ?? -1
        }
        guard status == 0 else { throw OSError(status: status) }
    }

}
