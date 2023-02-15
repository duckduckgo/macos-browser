//
//  NSNotification+NetPDistributed.swift
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

extension DistributedNotificationCenter.CenterType {
    static let networkProtection = DistributedNotificationCenter.CenterType("com.duckduckgo.DistributedNotificationCenter.CenterType.networkProtection")
}

extension NSNotification.Name {

    // MARK: - Connection Issues
    
    static let NetPConnectivityIssuesStarted = NSNotification.Name("com.duckduckgo.NetPConnectivityIssuesStarted")
    static let NetPConnectivityIssuesResolved = NSNotification.Name("com.duckduckgo.NetPConnectivityIssuesResolved")

    // MARK: - Connection Changes

    static let NetPServerSelected = NSNotification.Name("com.duckduckgo.NetPServerSelected")
    
    // MARK: - Error Events

    static let NetPTunnelErrorStatusChanged = Notification.Name(rawValue: "com.duckduckgo.NetPTunnelErrorStatusChanged")
    static let NetPControllerErrorStatusChanged = Notification.Name(rawValue: "com.duckduckgo.NetPControllerErrorStatusChanged")
    
    // MARK: - networkProtectionXPCService
    
    static let NetPIPCListenerStarted = NSNotification.Name("com.duckduckgo.NetPIPCListenerStarted")
}
