//
//  main.swift
//  NetworkProtectionExtensionmacOS
//
//  Created by DDG on 04/11/22.
//

import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
