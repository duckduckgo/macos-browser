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

final class PreviewScheduler: DataBrokerProtectionScheduler {
    @Published public var status: DataBrokerProtectionSchedulerStatus = .stopped
    public var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher { $status}

    internal init() {
        self.status = .idle
    }

    func start(showWebView: Bool) { }
    func forceRunOperations(showWebView: Bool) { }
    func stop() { }
    func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) { }

}

final class PreviewDataManager: DataBrokerProtectionDataManaging {
    var delegate: DataBrokerProtectionDataManagerDelegate?

    init(fakeBrokerFlag: FakeBrokerFlag) { }

    init() { }

    func saveProfile(_ profile: DataBrokerProtectionProfile) { }

    func fetchProfile(ignoresCache: Bool) -> DataBrokerProtectionProfile? {
        return nil
    }

    func fetchDataBrokerInfoData(ignoresCache: Bool) -> [DataBrokerInfoData] {
        [DataBrokerInfoData]()
    }

    func fetchBrokerProfileQueryData(ignoresCache: Bool) -> [BrokerProfileQueryData] {
        [BrokerProfileQueryData]()
    }
}
