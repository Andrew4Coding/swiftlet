//
//  CropGeometry.swift
//  Swiftlet
//

import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum CropHandle: CaseIterable, Hashable {
    case topLeading, top, topTrailing
    case leading, trailing
    case bottomLeading, bottom, bottomTrailing

    var anchorX: Int {
        switch self {
        case .topLeading, .leading, .bottomLeading: -1
        case .top, .bottom: 0
        case .topTrailing, .trailing, .bottomTrailing: 1
        }
    }

    var anchorY: Int {
        switch self {
        case .topLeading, .top, .topTrailing: -1
        case .leading, .trailing: 0
        case .bottomLeading, .bottom, .bottomTrailing: 1
        }
    }

    var isCorner: Bool { anchorX != 0 && anchorY != 0 }

    var accessibilityName: String {
        switch self {
        case .topLeading: "Top left corner"
        case .top: "Top edge"
        case .topTrailing: "Top right corner"
        case .leading: "Left edge"
        case .trailing: "Right edge"
        case .bottomLeading: "Bottom left corner"
        case .bottom: "Bottom edge"
        case .bottomTrailing: "Bottom right corner"
        }
    }
}

nonisolated enum CropGeometry {
    static let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
    static let minimumSide: CGFloat = 0.12

    static func resize(_ start: CGRect, handle: CropHandle, by translation: CGSize) -> CGRect {
        var minX = start.minX
        var maxX = start.maxX
        var minY = start.minY
        var maxY = start.maxY

        switch handle.anchorX {
        case -1: minX = clamp(start.minX + translation.width, 0, start.maxX - minimumSide)
        case 1: maxX = clamp(start.maxX + translation.width, start.minX + minimumSide, 1)
        default: break
        }
        switch handle.anchorY {
        case -1: minY = clamp(start.minY + translation.height, 0, start.maxY - minimumSide)
        case 1: maxY = clamp(start.maxY + translation.height, start.minY + minimumSide, 1)
        default: break
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func move(_ start: CGRect, by translation: CGSize) -> CGRect {
        CGRect(
            x: clamp(start.minX + translation.width, 0, 1 - start.width),
            y: clamp(start.minY + translation.height, 0, 1 - start.height),
            width: start.width,
            height: start.height
        )
    }

    static func nudge(_ rect: CGRect, handle: CropHandle, inward: Bool, step: CGFloat = 0.02) -> CGRect {
        let sign: CGFloat = inward ? 1 : -1
        let translation = CGSize(
            width: -CGFloat(handle.anchorX) * step * sign,
            height: -CGFloat(handle.anchorY) * step * sign
        )
        return resize(rect, handle: handle, by: translation)
    }

    #if canImport(UIKit)
    static func crop(_ image: UIImage, to normalized: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let pixels = CGRect(
            x: (normalized.minX * width).rounded(.down),
            y: (normalized.minY * height).rounded(.down),
            width: (normalized.width * width).rounded(.up),
            height: (normalized.height * height).rounded(.up)
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !pixels.isEmpty, let cropped = cgImage.cropping(to: pixels) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
    #endif

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
