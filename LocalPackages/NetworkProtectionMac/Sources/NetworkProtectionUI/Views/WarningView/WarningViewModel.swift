//
//  WarningViewModel.swift
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

import SwiftUI

extension WarningView {
    final class Model: ObservableObject {
        var message: String
        var actionTitle: String?
        var action: (() -> Void)?

        init(message: String,
             actionTitle: String? = nil,
             action: (() -> Void)?) {
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }
    }
}
