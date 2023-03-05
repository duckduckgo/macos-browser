//
//  EnableSyncView.swift
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

public protocol EnableSyncViewModel: ObservableObject {
    associatedtype SyncUserText: EnableSyncViewModelUserText

    func endFlow()
    func turnOnSync()
}

public protocol EnableSyncViewModelUserText {
    static var turnOnSyncQuestion: String { get }
    static var turnOnSyncExplanation1: String { get }
    static var turnOnSyncExplanation2: String { get }
    static var cancel: String { get }
    static var turnOnSync: String { get }
}

public struct EnableSyncView<ViewModel>: View where ViewModel: EnableSyncViewModel {

    @EnvironmentObject public var model: ViewModel

    public init() {}

    public var body: some View {
        SyncWizardStep {
            VStack(spacing: 20) {
                Image("SyncTurnOnDialog")
                Text(ViewModel.SyncUserText.turnOnSyncQuestion)
                    .font(.system(size: 17, weight: .bold))
                Text(ViewModel.SyncUserText.turnOnSyncExplanation1)
                    .multilineTextAlignment(.center)
                Text(ViewModel.SyncUserText.turnOnSyncExplanation2)
                    .multilineTextAlignment(.center)
            }
        } buttons: {
            Button(ViewModel.SyncUserText.cancel) {
                model.endFlow()
            }
            Button(ViewModel.SyncUserText.turnOnSync) {
                model.turnOnSync()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 360, height: 314)
    }
}
