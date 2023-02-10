//
//  Logger.swift
//  NetworkProtectionExtensionmacOS
//
//  Created by Diego Rey Mendez on 07/11/22.
//

import Foundation
import OSLog

let networkExtensionLog: OSLog = {
    #if NETP && DEBUG
        let subsystem = "DuckDuckGo Network Protection System Extension"
        return OSLog(subsystem: subsystem, category: "log")
    #else
        .disabled
    #endif
}()
