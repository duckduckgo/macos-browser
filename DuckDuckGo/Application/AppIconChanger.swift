//
//  AppIconChanger.swift
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

import Cocoa
import Combine
import BrowserServicesKit

final class AppIconChanger {

    init(internalUserDecider: InternalUserDecider) {
        subscribeToIsInternal(internalUserDecider)
    }

    func updateIcon(isInternalChannel: Bool) {
        let icon: NSImage?
        if isInternalChannel {
#if DEBUG
            icon = .internalChannelIconDebug
#elseif REVIEW
            icon = .internalChannelIconReview
#else
            icon = .internalChannelIcon
#endif
        } else {
            icon = nil
        }

        NSApplication.shared.applicationIconImage = icon
    }

    private var isInternalCancellable: AnyCancellable?

    private func subscribeToIsInternal(_ internalUserDecider: InternalUserDecider) {
        isInternalCancellable = internalUserDecider.isInternalUserPublisher
            .sink { [weak self] isInternal in
                self?.updateIcon(isInternalChannel: isInternal)
            }
    }

}
