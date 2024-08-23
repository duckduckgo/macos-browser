//
//  File.swift
//  
//
//  Created by Federico Cappelli on 23/08/2024.
//

import Foundation
import os.log

extension Logger {
    static var udsHelper = { Logger(subsystem: "UDS Helper", category: "") }()
}
