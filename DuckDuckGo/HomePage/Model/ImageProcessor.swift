//
//  ImageProcessor.swift
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

import AppKitExtensions
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ImageProcessingError: Error {
    case failedToReadImageData
    case failedToWriteImageData
    case failedToCorrectImageOrientation
    case failedToSaveImage
}

protocol ImageProcessing {
    func convertImageToJPEG(at url: URL) throws -> Data
    func resizeImage(at url: URL, to newSize: CGSize) -> Data?
    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme
}

final class ImageProcessor: ImageProcessing {

    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme {
        guard let averageBrightness = NSImage(contentsOf: url)?.averageBrightness() else { return .light }
        return averageBrightness > 0.5 ? .light : .dark
    }

    func convertImageToJPEG(at url: URL) throws -> Data {
        // Create a CGImageSource from the source image data
        guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ImageProcessingError.failedToReadImageData
        }

        // Create a mutable data object to hold the JPEG data
        let mutableData = NSMutableData()

        // Create a CGImageDestination for the JPEG format
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageProcessingError.failedToWriteImageData
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let orientationRawValue = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: orientationRawValue) ?? .up

        guard let correctedCGImage = correctImageOrientation(cgImage: cgImage, orientation: orientation) else {
            throw ImageProcessingError.failedToCorrectImageOrientation
        }

        // Add the CGImage to the destination
        CGImageDestinationAddImage(imageDestination, correctedCGImage, nil)

        // Finalize the image destination to write the data
        guard CGImageDestinationFinalize(imageDestination) else {
            throw ImageProcessingError.failedToSaveImage
        }

        return mutableData as Data
    }

    func correctImageOrientation(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
        var transform = CGAffineTransform.identity
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        switch orientation {
        case .up, .upMirrored:
            break
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.rotated(by: .pi / 2)
            transform = transform.scaledBy(x: width/height, y: height/width)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: width)
            transform = transform.rotated(by: -.pi / 2)
            transform = transform.scaledBy(x: width/height, y: height/width)
        }

        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        let contextSize: CGSize = {
            switch orientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                CGSize(width: height, height: width)
            default:
                CGSize(width: width, height: height)
            }
        }()

        guard let context = CGContext(
            data: nil,
            width: Int(contextSize.width),
            height: Int(contextSize.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: cgImage.bytesPerRow,
            space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.concatenate(transform)

        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return context.makeImage()
    }

    func resizeImage(at url: URL, to newSize: CGSize) -> Data? {
        guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let originalImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            return nil
        }

        let originalWidth = CGFloat(originalImage.width)
        let originalHeight = CGFloat(originalImage.height)

        let widthRatio = newSize.width / originalWidth
        let heightRatio = newSize.height / originalHeight
        let scale = max(widthRatio, heightRatio)

        let scaledWidth = newSize.width / scale
        let scaledHeight = newSize.height / scale

        let xOffset = (originalWidth - scaledWidth) / 2
        let yOffset = (originalHeight - scaledHeight) / 2

        let cropRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)

        guard let croppedImage = originalImage.cropping(to: cropRect) else {
            // pixel/error
            return data
        }

        let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: originalImage.bitsPerComponent,
            bytesPerRow: originalImage.bytesPerRow,
            space: originalImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(croppedImage, in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = context?.makeImage() else {
            // pixel/error
            return data
        }

        let mutableData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            // pixel/error
            return data
        }

        CGImageDestinationAddImage(imageDestination, resizedImage, nil)
        CGImageDestinationFinalize(imageDestination)

        return mutableData as Data
    }

}
