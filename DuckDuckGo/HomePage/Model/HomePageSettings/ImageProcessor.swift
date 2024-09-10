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

enum ImageProcessingError: Error, CustomNSError {
    case failedToReadImageData
    case failedToWriteImageData
    case failedToInitializeGraphicsContext
    case failedToCorrectImageOrientation
    case failedToSaveImage
    case failedToCropImage
    case failedToResizeImage

    static var errorDomain: String = "ImageProcessingError"

    var errorCode: Int {
        switch self {
        case .failedToReadImageData: return 1
        case .failedToWriteImageData: return 2
        case .failedToInitializeGraphicsContext: return 3
        case .failedToCorrectImageOrientation: return 4
        case .failedToSaveImage: return 5
        case .failedToCropImage: return 6
        case .failedToResizeImage: return 7
        }
    }
}

protocol ImageProcessing {
    func convertImageToJPEG(at url: URL) throws -> Data
    func resizeImage(with data: Data, to newSize: CGSize) throws -> Data
    func calculatePreferredColorScheme(forImageAt url: URL) -> ColorScheme
}

/**
 * This class is responsible by processing user-provided New Tab Page background images.
 *
 * It has the following responsibilities:
 * * converting input files to JPEG – if they already are JPEG, then they're still
 *   processed by correcting orientation in case it's not `.up`,
 * * creating thumbnails (by resizing images),
 * * calculating preferred color scheme by analyzing image brightness.
 *
 * > Related links:
 * [Tech Design](https://app.asana.com/0/481882893211075/1208090992610433/f)
 */
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

        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
           let orientationRawValue = properties[kCGImagePropertyOrientation] as? UInt32,
           let orientation = CGImagePropertyOrientation(rawValue: orientationRawValue),
           orientation != .up {

            // transform the image according to the orientation
            guard let correctedCGImage = correctImageOrientation(cgImage: cgImage, orientation: orientation) else {
                throw ImageProcessingError.failedToCorrectImageOrientation
            }

            CGImageDestinationAddImage(imageDestination, correctedCGImage, nil)
        } else {
            CGImageDestinationAddImage(imageDestination, cgImage, nil)
        }

        // Finalize the image destination to write the data
        guard CGImageDestinationFinalize(imageDestination) else {
            throw ImageProcessingError.failedToSaveImage
        }

        return mutableData as Data
    }

    private func correctImageOrientation(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
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

    func resizeImage(with data: Data, to newSize: CGSize) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let originalImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ImageProcessingError.failedToReadImageData
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
            throw ImageProcessingError.failedToCropImage
        }

        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: originalImage.bitsPerComponent,
            bytesPerRow: 0, // calculate automatically
            space: originalImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: originalImage.bitmapInfo.rawValue
        ) else {
            throw ImageProcessingError.failedToInitializeGraphicsContext
        }

        context.draw(croppedImage, in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = context.makeImage() else {
            throw ImageProcessingError.failedToResizeImage
        }

        let mutableData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageProcessingError.failedToWriteImageData
        }

        CGImageDestinationAddImage(imageDestination, resizedImage, nil)
        CGImageDestinationFinalize(imageDestination)

        return mutableData as Data
    }

}
