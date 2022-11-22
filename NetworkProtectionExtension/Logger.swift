//
//  Logger.swift
//  NetworkProtectionExtensionmacOS
//
//  Created by Diego Rey Mendez on 07/11/22.
//

import Foundation
import OSLog

let vpnLog: OSLog = {
    let subsystem = Bundle(for: PacketTunnelProvider.self).bundleIdentifier ?? "com.duckduckgo.NetworkProtectionExtension"

    return OSLog(subsystem: subsystem, category: "log")
}()
