//
//  ContextualOnboardingDialogTypeProvider.swift
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

import Foundation

protocol ContextualOnboardingDialogTypeProviding {
    func dialogTypeForTab(_ tab: Tab) -> ContextualDialogType?
}

enum ContextualDialogType: Equatable {
    case tryASearch
    case searchDone(shouldFollowUp: Bool)
    case tryASite
    case trackers(message: NSAttributedString, shouldFollowUp: Bool)
    case tryFireButton
    case highFive
}

struct ContextualOnboardingDialogTypeProvider: ContextualOnboardingDialogTypeProviding {
    func dialogTypeForTab(_ tab: Tab) -> ContextualDialogType? {
        guard case .url = tab.content else {
            return nil
        }
        return nil
    }
}
