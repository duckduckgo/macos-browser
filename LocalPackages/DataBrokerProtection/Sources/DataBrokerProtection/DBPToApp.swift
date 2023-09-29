//
//  DBPToApp.swift
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
import Common

public protocol DBPPackageToMainAppInterface {
    func profileModified()
    func startScanPressed()

    // Legacy function kept for debugging purposes. They should be deleted where possible
    func startScheduler(showWebView: Bool)
    func stopScheduler()
    func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) // TODO can delete?
    func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?)
    func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?)
    func runAllOperations(showWebView: Bool)
}

//I'm not sure how to do this way aroung right now
@objc public protocol MainAppToDBPPackageInterface {
    func brokersScanCompleted()
}
