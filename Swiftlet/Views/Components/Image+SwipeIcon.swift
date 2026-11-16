import SwiftUI
import UIKit

extension Image {
    static func swipeIcon(_ systemName: String, color: Color = Color.ds(.onAccent)) -> Image {
        guard let image = UIImage(systemName: systemName)?
            .withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
        else { return Image(systemName: systemName) }
        return Image(uiImage: image)
    }
}
