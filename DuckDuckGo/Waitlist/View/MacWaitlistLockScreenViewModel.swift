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

extension Notification.Name {
    static let macWaitlistLockScreenDidUnlock = Notification.Name("macWaitlistLockScreenDidUnlock")
}

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
        if state == .unlockRequestInFlight {
            if !AppDelegate.isRunningTests {
                assertionFailure("Attempted to unlock while a request was active")
            }
            
            return
        }
        
        state = .unlockRequestInFlight

        #warning("Don't ship this, it's for product review only so that people can test the flow repeatedly")
        let hardcodedTemporaryPasscode = "DAX"
        
        if code.caseInsensitiveCompare(hardcodedTemporaryPasscode) == .orderedSame {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.store.unlock()
                self.state = .unlockSuccess
            }
        } else {
            waitlistRequest.unlock(with: code) { result in
                switch result {
                case .success(let response):
                    if response.hasExpectedStatusMessage {
                        self.store.unlock()
                        self.state = .unlockSuccess
                    } else {
                        self.state = .unlockFailure
                    }
                case .failure:
                    self.state = .unlockFailure
                }
            }
        }
    }
    
}
