//
//  ManagementView.swift
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

enum Const {
    enum Fonts {
        static let preferencePaneTitle: Font = {
            if #available(macOS 11.0, *) {
                return .title2.weight(.semibold)
            } else {
                return .system(size: 17, weight: .semibold)
            }
        }()

        static let preferencePaneSectionHeader: Font = {
            if #available(macOS 11.0, *) {
                return .title3.weight(.semibold)
            } else {
                return .system(size: 15, weight: .semibold)
            }
        }()

        static let preferencePaneCaption: Font = {
            if #available(macOS 11.0, *) {
                return .subheadline
            } else {
                return .system(size: 10)
            }
        }()
    }
}

public struct ManagementView<ViewModel>: View where ViewModel: ManagementViewModel {
    @ObservedObject public var model: ViewModel

    public init(model: ViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(UserText.sync)
                .font(Const.Fonts.preferencePaneTitle)

            if model.isSyncEnabled {
                SyncEnabledView<ViewModel>()
                    .environmentObject(model)
            } else {
                SyncSetupView<ViewModel>()
                    .environmentObject(model)
            }
        }
        .alert(isPresented: $model.shouldShowErrorMessage) {
            Alert(title: Text("Unable to turn on Sync"), message: Text(model.errorMessage ?? "An error occurred"), dismissButton: .default(Text(UserText.ok)))
        }
    }
}
