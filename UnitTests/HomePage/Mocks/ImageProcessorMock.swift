//
//  ImageProcessorMock.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

@testable import DuckDuckGo_Privacy_Browser
import Foundation
import SwiftUI

final class ImageProcessorMock: ImageProcessing {

    var convertImageToJPEG: (URL) throws -> Data = { _ in Data() }
    var resizeImage: (Data, CGSize) throws -> Data = { data, _ in data }
    var calculatePreferredColorScheme: (URL) -> ColorScheme = { _ in .light }

    func convertImageToJPEG(at url: URL) throws -> Data {
        try convertImageToJPEG(url)
    }

    func resizeImage(with data: Data, to newSize: CGSize) throws -> Data {
        try resizeImage(data, newSize)
    }

    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme {
        calculatePreferredColorScheme(url)
    }
}
