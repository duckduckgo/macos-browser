//
//  FeedbackFormView.swift
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
import SwiftUI

struct FeedbackFormView: View {

    private enum Constants {
        static let headerPadding = 20.0
        static let bodyPadding = 20.0
    }

    struct ViewSize {
        fileprivate(set) var headerHeight: Double = 0.0
        fileprivate(set) var viewHeight: Double = 0.0
        fileprivate(set) var spacerHeight: Double = 0.0
        fileprivate(set) var buttonsHeight: Double = 0.0

        var totalHeight: Double {
            headerHeight + 2 * Constants.headerPadding + viewHeight + 4 * Constants.bodyPadding + spacerHeight + buttonsHeight
        }
    }

    @EnvironmentObject var viewModel: FeedbackFormViewModel

    let sizeChanged: (CGFloat) -> Void

    @State var viewSize: ViewSize = .init() {
        didSet {
            sizeChanged(viewSize.totalHeight)
        }
    }

    @State var notifyMeAbout: String = "Direct Messages"
    @State var playNotificationSounds: Bool = false
    @State var profileImageSize: String = "Large"

    var body: some View {
        Text("Body Goes Here")

        Picker(selection: $viewModel.selectedOption) {
            ForEach(viewModel.options) { option in
                Text(option.title).tag(option.title)
            }
        }
    }

}
