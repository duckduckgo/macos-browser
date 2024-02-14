//
//  TransparentProxyRequest.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import NetworkExtension

public enum TransparentProxyMessage: Codable {
    case changeSetting(_ change: TransparentProxySettings.Change)
}

/// A request for the TransparentProxyProvider.
///
/// This enum associates a request with a response handler making XPC communication simpler.
/// Once the request completes, `responseHandler` will be called with the result.
///
public enum TransparentProxyRequest {
    case changeSetting(_ settingChange: TransparentProxySettings.Change, responseHandler: () -> Void)

    var message: TransparentProxyMessage {
        switch self {
        case .changeSetting(let change, _):
            return .changeSetting(change)
        }
    }

    func handleResponse(data: Data?) {
        switch self {
        case .changeSetting(_, let handleResponse):
            handleResponse()
        }
    }
}

/// Respresents a transparent proxy session.
///
/// Offers basic IPC communication support for the app that owns the proxy.  This mechanism
/// is implemented through `NETunnelProviderSession` which means only the app that
/// owns the proxy can use this class.
///
public class TransparentProxySession {

    private let session: NETunnelProviderSession

    init(_ session: NETunnelProviderSession) {
        self.session = session
    }

    func send(_ request: TransparentProxyRequest) throws {
        let payload = try JSONEncoder().encode(request.message)
        try session.sendProviderMessage(payload, responseHandler: request.handleResponse(data:))
    }
}
