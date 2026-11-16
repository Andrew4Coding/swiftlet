import SwiftData
import SwiftUI

@main
struct SwiftletMacApp: App {
    private let container = Persistance.container

    var body: some Scene {
        WindowGroup {
            Text("Swiftlet")
        }
        .modelContainer(container)
    }
}
