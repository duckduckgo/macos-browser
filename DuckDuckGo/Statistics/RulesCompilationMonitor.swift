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

typealias ContentBlockingAssetsCompilationTimeReporter = AbstractContentBlockingAssetsCompilationTimeReporter<UInt64>
extension ContentBlockingAssetsCompilationTimeReporter {
    static let shared = ContentBlockingAssetsCompilationTimeReporter()
}

final class AbstractContentBlockingAssetsCompilationTimeReporter<Caller: Hashable>: NSObject {

    var currentTime: () -> TimeInterval = CACurrentMediaTime

    private var waitStart: TimeInterval?
    private var waiters = Set<Caller>()
    private var isFinished = false

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    private var onboardingFinished: Bool
    private var onboardingShown: Bool!

    override init() {
        super.init()
        self.onboardingShown = !onboardingFinished
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate(_:)),
                                               name: NSApplication.willTerminateNotification,
                                               object: nil)
    }

    /// Called when a Tab is going  to wait for Content Blocking Rules compilation
    func tabWillWaitForRulesCompilation(_ tab: Caller) {
        guard !isFinished else { return }

        waiters.insert(tab)
        if waitStart == nil {
            waitStart = currentTime()
        }
    }

    private func report(waitTime: TimeInterval, result: GeneralPixel.WaitResult, completionHandler: @escaping ((Error?) -> Void) = { _ in }) {
        // report only once
        isFinished = true
        completionHandler(nil)

        // This is temporarily disabled:
        //
        // PixelKit.fire(GeneralPixel.compileRulesWait(onboardingShown: self.onboardingShown, waitTime: waitTime, result: result),
        //            withAdditionalParameters: ["waitTime": String(waitTime)],
        //            onComplete: completionHandler)

    }

    /// Called when Rules compilation finishes
    func reportWaitTimeForTabFinishedWaitingForRules(_ tab: Caller) {
        defer { waiters.remove(tab) }
        guard waiters.contains(tab),
              !isFinished,
              let waitStart = waitStart
        else { return }

        report(waitTime: currentTime() - waitStart, result: .success)
    }

    /// If Tab is going to close while the rules are still being compiled: report wait time with Tab .closed argument
    func tabWillClose(_ tab: Caller) {
        defer { waiters.remove(tab) }
        guard waiters.contains(tab),
              !isFinished,
              let waitStart = self.waitStart
        else { return }

        report(waitTime: currentTime() - waitStart, result: .closed)
    }

    /// If App is going to close while the rules are still being compiled: report wait time with .quit argument
    @objc func applicationWillTerminate(_: Notification) {
        guard !isFinished,
              waiters.count > 0,
              let waitStart = self.waitStart
        else { return }
        // Run the loop until Pixel is sent
        let condition = RunLoop.ResumeCondition()
        report(waitTime: currentTime() - waitStart, result: .quit) { _ in
            condition.resolve()
        }
        RunLoop.current.run(until: condition)
    }

    /// When Navigation while Content Blocking Rules are already available
    func reportNavigationDidNotWaitForRules() {
        guard !isFinished else { return }
        report(waitTime: 0, result: .success)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
