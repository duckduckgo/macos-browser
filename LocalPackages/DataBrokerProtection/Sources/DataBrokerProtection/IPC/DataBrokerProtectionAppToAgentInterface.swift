//
//  DataBrokerProtectionAppToAgentInterface.swift
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

public enum DataBrokerProtectionAppToAgentInterfaceError: Error {
    case loginItemDoesNotHaveNecessaryPermissions
    case appInWrongDirectory
}

@objc
public class DataBrokerProtectionAgentErrorCollection: NSObject, NSSecureCoding {
    /*
     This needs to be an NSObject (rather than a struct) so it can be represented in Objective C
     and confrom to NSSecureCoding for the IPC layer.
     */

    private enum NSSecureCodingKeys {
        static let oneTimeError = "oneTimeError"
        static let operationErrors = "operationErrors"
    }

    public let oneTimeError: Error?
    public let operationErrors: [Error]?

    public init(oneTimeError: Error? = nil, operationErrors: [Error]? = nil) {
        self.oneTimeError = oneTimeError
        self.operationErrors = operationErrors
        super.init()
    }

    // MARK: - NSSecureCoding

    public static let supportsSecureCoding = true

    public func encode(with coder: NSCoder) {
        coder.encode(oneTimeError, forKey: NSSecureCodingKeys.oneTimeError)
        coder.encode(operationErrors, forKey: NSSecureCodingKeys.operationErrors)
    }

    public required init?(coder: NSCoder) {
        oneTimeError = coder.decodeObject(of: NSError.self, forKey: NSSecureCodingKeys.oneTimeError)
        operationErrors = coder.decodeArrayOfObjects(ofClass: NSError.self, forKey: NSSecureCodingKeys.operationErrors)
    }
}

public protocol DataBrokerProtectionAgentAppEvents {
    func profileSaved()
    func appLaunched()
}

public protocol DataBrokerProtectionAgentDebugCommands {
    func openBrowser(domain: String)
    func startImmediateOperations(showWebView: Bool)
    func startScheduledOperations(showWebView: Bool)
    func runAllOptOuts(showWebView: Bool)
    func getDebugMetadata() async -> DBPBackgroundAgentMetadata?
}

public protocol DataBrokerProtectionAppToAgentInterface: AnyObject, DataBrokerProtectionAgentAppEvents, DataBrokerProtectionAgentDebugCommands {

}
