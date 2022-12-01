//
//  main.swift
//  NetworkProtectionExtensionmacOS
//
//  Created by Diego Rey Mendez on 04/11/22.
//

import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
