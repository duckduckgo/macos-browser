//
//  SyncAnotherDeviceView.swift
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

import SwiftUI
import SwiftUIExtensions

public protocol SyncAnotherDeviceViewModel: ObservableObject {
    associatedtype SyncAnotherDeviceViewUserText: SyncUI.SyncAnotherDeviceViewUserText

    func endFlow()
    func turnOnSync()
}

public protocol SyncAnotherDeviceViewUserText {
    static var syncAnotherDeviceTitle: String { get }
    static var syncAnotherDeviceExplanation1: String { get }
    static var syncAnotherDeviceExplanation2: String { get }
    static var notNow: String { get }
    static var syncAnotherDevice: String { get }
}

public struct SyncAnotherDeviceView<ViewModel>: View where ViewModel: SyncAnotherDeviceViewModel {
    typealias UserText = ViewModel.SyncAnotherDeviceViewUserText

    @EnvironmentObject public var model: ViewModel

    public init() {}

    public var body: some View {
        SyncDialog {
            VStack(spacing: 20) {
                Image("SyncAnotherDeviceDialog")
                Text(UserText.syncAnotherDeviceTitle)
                    .font(.system(size: 17, weight: .bold))
                Text(UserText.syncAnotherDeviceExplanation1)
                    .multilineTextAlignment(.center)
                Text(UserText.syncAnotherDeviceExplanation2)
                    .multilineTextAlignment(.center)
            }
        } buttons: {
            Button(UserText.notNow) {
                model.endFlow()
            }
            Button(UserText.syncAnotherDevice) {
                model.endFlow()
//                model.presentSyncAnotherDeviceDialog()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 360, height: 314)
    }
}
