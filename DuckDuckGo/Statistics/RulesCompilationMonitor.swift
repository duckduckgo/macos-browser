//
//  RulesCompilationMonitor.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class RulesCompilationMonitor: NSObject {
    static let shared = RulesCompilationMonitor()
    private var waitStart: TimeInterval?
    private var waiters = Set<Tab>()
    private var isFinished = false

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    private var onboardingFinished: Bool
    private var onboardingShown: Bool!

    private override init() {
        super.init()
        self.onboardingShown = !onboardingFinished
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate(_:)),
                                               name: NSApplication.willTerminateNotification,
                                               object: nil)
    }

    func tabWillWaitForRulesCompilation(_ tab: Tab) {
        guard !isFinished else { return }

        waiters.insert(tab)
        if waitStart == nil {
            waitStart = CACurrentMediaTime()
        }
    }

    func tab(_ tab: Tab, didFinishWaitingForRulesWithWaitTime waitTime: TimeInterval?) {
        guard waiters.remove(tab) != nil, waiters.isEmpty else { return }

        if let waitTime = waitTime {
            Pixel.fire(.compileRulesWait(onboardingShown: self.onboardingShown, waitTime: waitTime, result: .success))
        }

        // report only once
        isFinished = true
    }

    func tabWillClose(_ tab: Tab) {
        guard waiters.remove(tab) != nil,
              !isFinished,
              let waitStart = self.waitStart
        else { return }

        Pixel.fire(.compileRulesWait(onboardingShown: self.onboardingShown, waitTime: CACurrentMediaTime() - waitStart, result: .closed))

        // report only once
        isFinished = true
    }

    @objc func applicationWillTerminate(_: Notification) {
        guard !isFinished,
              !waiters.isEmpty,
              let waitStart = self.waitStart
        else { return }

        let condition = RunLoop.ResumeCondition()
        Pixel.fire(.compileRulesWait(onboardingShown: self.onboardingShown, waitTime: CACurrentMediaTime() - waitStart, result: .quit)) { _ in
            condition.resolve()
        }
        RunLoop.current.run(until: condition)
    }

}
