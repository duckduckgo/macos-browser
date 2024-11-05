//
//  AIChatToolBarPopUpOnboardingViewModel.swift
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

import PixelKit

final class AIChatToolBarPopUpOnboardingViewModel: ObservableObject {
    var aiChatStorage: AIChatPreferencesStorage
    var ctaCallback: ((Bool) -> Void)?

    internal init(aiChatStorage: any AIChatPreferencesStorage = DefaultAIChatPreferencesStorage(),
                  ctaCallback: ((Bool) -> Void)? = nil) {
        self.aiChatStorage = aiChatStorage
        self.ctaCallback = ctaCallback
    }

    func rejectToolbarIcon() {
        aiChatStorage.shouldDisplayToolbarShortcut = false
        ctaCallback?(false)
    }

    func acceptToolbarIcon() {
        PixelKit.fire(GeneralPixel.aichatToolbarOnboardingPopoverAccept,
                      includeAppVersionParameter: true)
        aiChatStorage.shouldDisplayToolbarShortcut = true
        ctaCallback?(true)
    }
}
