//
//  SwiftUIPreviewHelper.swift
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

/// Convenience class for SwiftUI previews.
///
/// Do not use this for any production code.
///
final class DataBrokerProtectionNoOpScheduler: DataBrokerProtectionScheduler {

    private(set) public var status: DataBrokerProtectionSchedulerStatus = .idle

    private var internalStatusPublisher: Published<DataBrokerProtectionSchedulerStatus> = .init(initialValue: .idle)

    public var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher {
        internalStatusPublisher.projectedValue
    }

    func profileModified() { }
    //func startScanPressed() { }
    func startScheduler(showWebView: Bool) { }
    func stopScheduler() { }
    func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) { }
    func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?) { }
    func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) { }
    func runAllOperations(showWebView: Bool) { }
}
