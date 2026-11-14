//
//  ReceiptPreviewButton.swift
//  Swiftlet
//

import SwiftUI

struct ReceiptPreviewButton: View {
    let imageData: Data

    @State private var image: UIImage?
    @State private var isPresenting = false

    var body: some View {
        Group {
            if let image {
                Button {
                    isPresenting = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.footnote.weight(.semibold))
                                .padding(8)
                                .background(Color.ds(.surface), in: Circle())
                                .overlay(Circle().strokeBorder(Color.ds(.border), lineWidth: 0.5))
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Receipt photo")
                .accessibilityHint("Opens the photo full screen")
            }
        }
        .task(id: imageData) { image = UIImage(data: imageData) }
        .fullScreenCover(isPresented: $isPresenting) {
            ReceiptViewer(imageData: imageData) { isPresenting = false }
        }
    }
}

struct ReceiptThumbnail: View {
    let imageData: Data
    var size: CGFloat = 44

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.ds(.surfaceMuted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
        .task(id: imageData) { image = ReceiptImage.thumbnail(from: imageData, maxPixels: Int(size * 3)) }
    }
}
