//
//  FeedbackFormModel.swift
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
import Combine
import SwiftUI

final class FeedbackFormViewModel: ObservableObject {

    struct FeedbackFormOption: Identifiable, Equatable {
        let id: String
        let title: String
        let components: [any FeedbackFormComponent]

        static func == (lhs: FeedbackFormViewModel.FeedbackFormOption, rhs: FeedbackFormViewModel.FeedbackFormOption) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum ViewAction {
        case cancel
        case submit
    }

    let options: [FeedbackFormOption]

    @State var selectedOption: FeedbackFormOption

    init(options: [FeedbackFormOption]) {
        self.options = options

        guard let firstOption = options.first else {
            fatalError("FeedbackFormViewModel requires at least one option")
        }

        self.selectedOption = firstOption
    }

    func process(action: ViewAction) {
        switch action {
        case .cancel: break
        case .submit: break
        }
    }

}

enum FeedbackFormComponentType {
    case textField
    case textView
    case textBlock
}

protocol FeedbackFormComponent: Equatable {
    var componentType: FeedbackFormComponentType { get }
}

struct FeedbackFormComponentTextField: FeedbackFormComponent {
    let componentType = FeedbackFormComponentType.textField
    var textFieldValue: String = ""
}

struct FeedbackFormComponentTextView: FeedbackFormComponent {
    let componentType = FeedbackFormComponentType.textView
    var textViewValue: String = ""
}

struct FeedbackFormComponentTextBlock: FeedbackFormComponent {
    let componentType = FeedbackFormComponentType.textBlock
    let stringValue: String
}
