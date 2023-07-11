//
//  NetworkProtectionConnectionBandwidthAnalyzer.swift
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

import Foundation
import Common

/// Simple bandwidth analyzer that will provide some useful information based on the delta of two snapshots over time
///
/// This class was designed to be easy to modify to eventually handle more than two snapshots over time.
///
final class NetworkProtectionConnectionBandwidthAnalyzer {
    private struct Snapshot {
        let rxBytes: UInt64
        let txBytes: UInt64
        let date: Date
    }

    /// Right now we only support analyzing the last two entries, but this class could be expanded to offer bandwidth analysis
    /// for more samples.
    ///
    private static let maxEntries = 2
    private var entries = [Snapshot]()

    private static let rxThreshold = 100 * 1024 // 100k
    private static let txThreshold = 100 * 1024 // 100k

    private var idle = false {
        didSet {
            os_log("Connection set to idle: %{public}@", log: .networkProtectionBandwidthAnalysis, String(describing: idle))
        }
    }

    /// Records an entry with the provided rx and tx values and the current date.
    ///
    func record(rxBytes: UInt64, txBytes: UInt64) {
        let newEntry = Snapshot(rxBytes: rxBytes, txBytes: txBytes, date: Date())
        entries.insert(newEntry, at: 0)

        if entries.count > Self.maxEntries {
            entries = [Snapshot](entries.dropLast(entries.count - Self.maxEntries))
        }

        refreshConnectionIdle()
    }

    /// Prevents the connection from going idle.  This is useful when any code outside this class identifies a situation in which
    /// we don't want the connection to be marked as idle (even though the recorded entries may say otherwise).
    ///
    /// One example of where this may be useful is if the code that's meant to record new entries in the bandwidth analyzer cannot
    /// do so for unexpected reasons.
    ///
    func preventIdle() {
        idle = false
    }

    private func refreshConnectionIdle() {
        guard entries.count == 2 else {
            // If we don't yet have enough samples to analyze we'll stay safe and assume
            // the connection is in use.
            idle = false
            return
        }

        let newer = entries[0]
        let older = entries[1]

        guard newer.rxBytes > older.rxBytes && newer.txBytes > older.txBytes else {
            // If this is allowed, the code below may crash with an arythmetic overflow
            //
            idle = false
            return
        }

        let (rx, tx) = bytesPerSecond(newer: newer, older: older)

        os_log("Bytes per second in last time-interval: (rx: %{public}@, tx: %{public}@)", log: .networkProtectionBandwidthAnalysis, type: .info, String(describing: rx), String(describing: tx))

        idle = UInt64(rx) < Self.rxThreshold && UInt64(tx) < Self.txThreshold
    }

    func isConnectionIdle() -> Bool {
        idle
    }

    /// Useful when servers are swapped
    ///
    func reset() {
        os_log("Bandwidth analyzer reset", log: .networkProtectionBandwidthAnalysis, type: .info)
        entries.removeAll()
    }

    // MARK: - Delta Calculation

    private func bytesPerSecond(newer: Snapshot, older: Snapshot) -> (rx: Double, tx: Double) {
        let deltaSeconds = newer.date.timeIntervalSince1970 - older.date.timeIntervalSince1970
        let rx = Double(newer.rxBytes - older.rxBytes) / deltaSeconds
        let tx = Double(newer.txBytes - older.txBytes) / deltaSeconds

        return (rx, tx)
    }
}
