//
//  NetworkProtectionServerSelection.swift
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

protocol NetworkProtectionSelectedServerStore: AnyObject {

    var selectedServer: SelectedNetworkProtectionServer { get set }
    func reset()
}

public enum SelectedNetworkProtectionServer: Equatable {
    case automatic
    case endpoint(String)

    public var stringValue: String? {
        switch self {
        case .automatic: return nil
        case .endpoint(let endpoint): return endpoint
        }
    }
}

public final class NetworkProtectionSelectedServerUserDefaultsStore: NetworkProtectionSelectedServerStore {

    private enum Constants {
        static let selectedServerKey = "network-protection.selected-server-endpoint"
    }

    // MARK: - Server selection

    /// Returns the server endpoint selected by the user. The default value is `automatic`.
    ///
    /// - Note: This value may be out of sync with the real set of available backend endpoints.
    ///         Any callers that use this value will need to check the known source of truth before proceeding to use the endpoint.
    public var selectedServer: SelectedNetworkProtectionServer {
        get {
            guard let selectedEndpoint = self.userDefaults.string(forKey: Constants.selectedServerKey) else {
                return .automatic
            }

            return .endpoint(selectedEndpoint)
        }

        set {
            switch newValue {
            case .automatic:
                self.userDefaults.removeObject(forKey: Constants.selectedServerKey)
            case .endpoint(let endpoint):
                self.userDefaults.set(endpoint, forKey: Constants.selectedServerKey)
            }
        }
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func reset() {
        userDefaults.removeObject(forKey: Constants.selectedServerKey)
    }

}
