//
//  ReceiptCropView.swift
//  Swiftlet
//

import SwiftUI

struct ReceiptCropView: View {
    let image: UIImage
    let onUse: (UIImage) -> Void

    @State private var rect = CropGeometry.unit
    @State private var dragStart: CGRect?
    @State private var failedToCrop = false

    private let inset: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                cropCanvas(in: proxy.size)
            }

            VStack(spacing: 10) {
                Text("Drag the corners so only the receipt is inside.")
                    .dsTextStyle(.footnote, color: .textSecondary)
                    .multilineTextAlignment(.center)

                if failedToCrop {
                    Text("Couldn't crop that photo. Try again.")
                        .dsTextStyle(.footnote, color: .warning)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        resetButton
                        useButton
                    }
                    VStack(spacing: 10) {
                        useButton
                        resetButton
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .background(Color.ds(.canvas))
        .navigationTitle("Crop receipt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var useButton: some View {
        DSButton("Use photo") {
            if let cropped = CropGeometry.crop(image, to: rect) {
                onUse(cropped)
            } else {
                failedToCrop = true
            }
        }
    }

    private var resetButton: some View {
        DSButton("Reset", variant: .tertiary, fillsWidth: false) {
            withAnimation(.snappy) { rect = CropGeometry.unit }
        }
        .disabled(rect == CropGeometry.unit)
    }

    private func fittedRect(in size: CGSize) -> CGRect {
        let available = CGSize(width: max(size.width - inset * 2, 1), height: max(size.height - inset * 2, 1))
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: (size.width - fitted.width) / 2,
            y: (size.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private func cropCanvas(in size: CGSize) -> some View {
        let fitted = fittedRect(in: size)
        let frame = CGRect(
            x: fitted.minX + rect.minX * fitted.width,
            y: fitted.minY + rect.minY * fitted.height,
            width: rect.width * fitted.width,
            height: rect.height * fitted.height
        )

        return ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .frame(width: fitted.width, height: fitted.height)
                .offset(x: fitted.minX, y: fitted.minY)
                .accessibilityLabel("Receipt photo")

            Path { path in
                path.addRect(fitted)
                path.addRect(frame)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .contentShape(Rectangle())
                .gesture(moveGesture(fitted: fitted))
                .accessibilityHidden(true)

            ForEach(CropHandle.allCases, id: \.self) { handle in
                handleView(handle)
                    .position(position(of: handle, in: frame))
                    .gesture(resizeGesture(handle, fitted: fitted))
                    .accessibilityElement()
                    .accessibilityLabel(handle.accessibilityName)
                    .accessibilityValue(valueDescription)
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: rect = CropGeometry.nudge(rect, handle: handle, inward: true)
                        case .decrement: rect = CropGeometry.nudge(rect, handle: handle, inward: false)
                        @unknown default: break
                        }
                    }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var valueDescription: String {
        "Crop covers \(Int((rect.width * rect.height * 100).rounded())) percent of the photo"
    }

    @ViewBuilder
    private func handleView(_ handle: CropHandle) -> some View {
        ZStack {
            Color.clear.frame(width: 44, height: 44)
            if handle.isCorner {
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.35), radius: 2)
            } else {
                Capsule()
                    .fill(Color.white)
                    .frame(width: handle.anchorX == 0 ? 30 : 6, height: handle.anchorY == 0 ? 30 : 6)
                    .shadow(color: .black.opacity(0.35), radius: 2)
            }
        }
        .contentShape(Rectangle())
    }

    private func position(of handle: CropHandle, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.midX + CGFloat(handle.anchorX) * frame.width / 2,
            y: frame.midY + CGFloat(handle.anchorY) * frame.height / 2
        )
    }

    private func resizeGesture(_ handle: CropHandle, fitted: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? rect
                dragStart = start
                rect = CropGeometry.resize(start, handle: handle, by: normalized(value.translation, fitted))
            }
            .onEnded { _ in dragStart = nil }
    }

    private func moveGesture(fitted: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? rect
                dragStart = start
                rect = CropGeometry.move(start, by: normalized(value.translation, fitted))
            }
            .onEnded { _ in dragStart = nil }
    }

    private func normalized(_ translation: CGSize, _ fitted: CGRect) -> CGSize {
        CGSize(width: translation.width / fitted.width, height: translation.height / fitted.height)
    }
}
