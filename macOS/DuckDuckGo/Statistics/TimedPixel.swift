//
//  TimedPixel.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

struct TimedPixel {

    let pixel: Pixel.Event
    let time: CFTimeInterval

    init(_ pixel: Pixel.Event, time: CFTimeInterval = CACurrentMediaTime()) {
        self.pixel = pixel
        self.time = time
    }

    func fire(_ fireTime: CFTimeInterval = CACurrentMediaTime(), withAdditionalParmaeters params: [String: String] = [:]) {
        let duration = String(format: "%.1f", fireTime - self.time)
        var newParams = pixel.parameters ?? [:]
        newParams.merge(params, uniquingKeysWith: { $1 })
        newParams[Pixel.Parameters.duration] = duration
        Pixel.shared?.fire(pixelNamed: pixel.name, withAdditionalParameters: newParams)
    }

}
