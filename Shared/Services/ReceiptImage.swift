//
//  ReceiptImage.swift
//  Swiftlet
//
//  Created by Andrew Devito Aryo on 04/09/26.
//

import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum ReceiptImage {
    #if canImport(UIKit)
    static func compressedData(from image: UIImage, maxDimension: CGFloat = 2000) -> Data? {
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return normalized.jpegData(compressionQuality: 0.8)
    }

    static func upright(from data: Data, maxPixels: CGFloat = 4000) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        let factor = longest > maxPixels ? maxPixels / longest : 1
        let size = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    #else
    static func compressedData(from image: NSImage, maxDimension: CGFloat = 2000) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        return jpegData(from: cgImage, maxDimension: maxDimension)
    }

    static func compressedData(from data: Data, maxDimension: CGFloat = 2000) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return jpegData(from: cgImage, maxDimension: maxDimension)
    }

    static func upright(from data: Data, maxPixels: CGFloat = 4000) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixels),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }

    private static func jpegData(from cgImage: CGImage, maxDimension: CGFloat) -> Data? {
        let longest = CGFloat(max(cgImage.width, cgImage.height))
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let width = Int((CGFloat(cgImage.width) * scale).rounded())
        let height = Int((CGFloat(cgImage.height) * scale).rounded())
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, scaled, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
    #endif

    static func thumbnail(from data: Data, maxPixels: Int = 160) -> PlatformImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { cgImage in
            #if canImport(UIKit)
            UIImage(cgImage: cgImage)
            #else
            NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
            #endif
        }
    }
}
