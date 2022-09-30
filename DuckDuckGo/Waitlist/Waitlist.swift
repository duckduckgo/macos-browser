//
//  Waitlist.swift
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

struct Waitlist {
    
    static var isUnlocked: Bool {
        return MacWaitlistEncryptedFileStorage().isUnlocked()
    }
    
#if DEBUG || REVIEW
    static func unlockExistingInstallIfNecessary() {
        MacWaitlistEncryptedFileStorage().unlock()
    }
#endif
    
    static func displayLockScreenIfNecessary(in viewController: NSViewController) -> Bool {
        guard !isUnlocked else {
            return false
        }

        let lockScreenViewController = MacWaitlistLockScreenViewController.instantiate()
        let lockScreenWindow = lockScreenViewController.wrappedInWindowController()
        
        let currentSheets = viewController.view.window?.sheets ?? []
        let alreadyHasLockScreen = currentSheets.contains(where: { window in
            return window.contentViewController is MacWaitlistLockScreenViewController
        })
        
        if !alreadyHasLockScreen {
            viewController.beginSheet(lockScreenWindow)
            Pixel.fire(.waitlistPresentedLockScreen)
            return true
        }
        
        return false
    }
    
}
