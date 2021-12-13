//
//  MacWaitlistLockScreenViewModel.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class MacWaitlistLockScreenViewModel: ObservableObject {
    
    enum ViewState {
        case requiresUnlock
        case unlockRequestInFlight
        case unlockSuccess
        case unlockFailure
    }
    
    @Published var state: ViewState
    
    private let store: MacWaitlistStore
    private let waitlistRequest: MacWaitlistRequest
    
    init(store: MacWaitlistStore = MacWaitlistEncryptedFileStorage(), waitlistRequest: MacWaitlistRequest = MacWaitlistAPIRequest()) {
        self.store = store
        self.waitlistRequest = waitlistRequest
        
        self.state = .requiresUnlock
    }
    
    public func attemptUnlock(code: String) {
        self.state = .unlockRequestInFlight

        // TODO: Don't ship this, it's for product review only so that people can test the flow repeatedly
        let hardcodedTemporaryPasscode = "DAX"
        
        if code == hardcodedTemporaryPasscode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.state = .unlockSuccess
            }
        } else {
            self.state = .unlockFailure
        }
    }
    
}
