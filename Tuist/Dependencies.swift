//
//  Dependencies.swift
//  Config
//
//  Created by Dominik Kapusta on 17/03/2022.
//

import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: [
        .remote(url: "https://github.com/gumob/PunycodeSwift.git", requirement: .upToNextMajor(from: "2.1.0")),
        .remote(url: "https://github.com/AliSoftware/OHHTTPStubs.git", requirement: .upToNextMajor(from: "9.1.0")),
        .remote(url: "https://github.com/sparkle-project/Sparkle.git", requirement: .exact("1.27.1"))
    ],
    platforms: [.macOS]
)
