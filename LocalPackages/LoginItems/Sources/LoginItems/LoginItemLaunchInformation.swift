//
//  File.swift
//  
//
//  Created by ddg on 10/11/23.
//

import Foundation
import AppKit
import os.log

public struct LoginItemLaunchInformation: Equatable, Hashable {

    private let agentBundleID: String
    private let defaults: UserDefaults
    private let launchRecencyThreshold = 5.0

    public init(agentBundleID: String, defaults: UserDefaults) {
        self.agentBundleID = agentBundleID
        self.defaults = defaults
    }

    // MARK: - Launch Information

    private func systemBootTime() -> Date {
        var tv = timeval()
        var tvSize = MemoryLayout<timeval>.size
        let err = sysctlbyname("kern.boottime", &tv, &tvSize, nil, 0)
        guard err == 0, tvSize == MemoryLayout<timeval>.size else {
            return Date(timeIntervalSince1970: 0)
        }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000.0)
    }

    /// Lets the login item app know if it was launched by the computer startup.
    ///
    public var wasLaunchedByStartup: Bool {
        let lastSystemBootTime = self.systemBootTime()
        let lastRunTime = Date(timeIntervalSince1970: lastRunTimestamp)
        let lastEnabledTime = Date(timeIntervalSince1970: lastEnabledTimestamp)

        return lastSystemBootTime > lastRunTime
            && lastSystemBootTime > lastEnabledTime
    }

    /// The login item app should call this after checking `wasLaunchedByStartup`.
    ///
    public func update() {
        updateLastRunTimestamp()
    }

    // MARK: - Last Enabled

    private static let loginItemLastEnabledTimestampKey = "loginItemLastEnabledTimestampKey"

    private func lastEnabledKey(forAgentBundleID agentBundleID: String) -> String {
        Self.loginItemLastEnabledTimestampKey + "_" + agentBundleID
    }

    var lastEnabledTimestamp: TimeInterval {
        defaults.double(forKey: lastEnabledKey(forAgentBundleID: agentBundleID))
    }

    func updateLastEnabledTimestamp() {
        defaults.set(
            Date().timeIntervalSince1970,
            forKey: lastEnabledKey(forAgentBundleID: agentBundleID))
    }

    // MARK: - Last Run

    private static let loginItemLastRunTimestampKey = "loginItemLastRunTimestampKey"

    private func lastRunKey(forAgentBundleID agentBundleID: String) -> String {
        Self.loginItemLastRunTimestampKey + "_" + agentBundleID
    }

    var lastRunTimestamp: TimeInterval {
        defaults.double(forKey: lastRunKey(forAgentBundleID: agentBundleID))
    }

    func updateLastRunTimestamp() {
        defaults.set(
            Date().timeIntervalSince1970,
            forKey: lastRunKey(forAgentBundleID: agentBundleID))
    }
}
