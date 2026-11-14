//
//  CropGeometryTests.swift
//  SwiftletTests
//

import CoreGraphics
import Testing
import UIKit

@testable import Swiftlet

struct CropGeometryTests {
    private let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    @Test func draggingTopLeadingCornerShrinksFromThatCorner() {
        let rect = CropGeometry.resize(full, handle: .topLeading, by: CGSize(width: 0.2, height: 0.1))
        #expect(rect == CGRect(x: 0.2, y: 0.1, width: 0.8, height: 0.9))
    }

    @Test func edgeHandlesOnlyMoveTheirOwnAxis() {
        let rect = CropGeometry.resize(full, handle: .bottom, by: CGSize(width: 0.5, height: -0.3))
        #expect(rect.minX == 0 && rect.width == 1)
        #expect(abs(rect.height - 0.7) < 0.0001)
    }

    @Test func resizeNeverLeavesTheImage() {
        let rect = CropGeometry.resize(full, handle: .bottomTrailing, by: CGSize(width: 5, height: 5))
        #expect(rect == full)
        let shrunk = CropGeometry.resize(full, handle: .topLeading, by: CGSize(width: -5, height: -5))
        #expect(shrunk == full)
    }

    @Test func resizeKeepsAMinimumSize() {
        let rect = CropGeometry.resize(full, handle: .topLeading, by: CGSize(width: 5, height: 5))
        #expect(abs(rect.width - CropGeometry.minimumSide) < 0.0001)
        #expect(abs(rect.height - CropGeometry.minimumSide) < 0.0001)
        #expect(rect.maxX == 1 && rect.maxY == 1)
    }

    @Test func movingStaysInsideTheImage() {
        let start = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        #expect(CropGeometry.move(start, by: CGSize(width: 1, height: 1)) == CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        #expect(CropGeometry.move(start, by: CGSize(width: -1, height: -1)) == CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
    }

    @Test func nudgeMovesInwardAndOutwardForAccessibility() {
        let inward = CropGeometry.nudge(full, handle: .leading, inward: true)
        #expect(abs(inward.minX - 0.02) < 0.0001)
        let back = CropGeometry.nudge(inward, handle: .leading, inward: false)
        #expect(abs(back.minX) < 0.0001)
        let right = CropGeometry.nudge(full, handle: .trailing, inward: true)
        #expect(abs(right.maxX - 0.98) < 0.0001)
    }

    @Test func croppingOutputsOnlyTheSelectedPixels() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 400), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 200, width: 200, height: 200))
        }

        let cropped = try #require(CropGeometry.crop(image, to: CGRect(x: 0, y: 0.5, width: 1, height: 0.5)))
        #expect(cropped.cgImage?.width == 200)
        #expect(cropped.cgImage?.height == 200)

        let pixel = try #require(cropped.cgImage?.dataProvider?.data as Data?)
        #expect(pixel.count > 0)
        let blue = pixel[2]
        let red = pixel[0]
        #expect(blue > 200 && red < 50)
    }

    @Test func uprightImageIsCappedToMaximumPixels() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 300), format: format).image { _ in }
        let data = try #require(big.pngData())
        let image = try #require(ReceiptImage.upright(from: data, maxPixels: 300))
        #expect(image.size.width == 300)
        #expect(image.size.height == 150)
    }
}
