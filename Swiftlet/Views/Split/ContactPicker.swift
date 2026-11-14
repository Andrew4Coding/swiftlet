//
//  ContactPicker.swift
//  Swiftlet
//

import ContactsUI
import SwiftUI

struct ContactPicker: UIViewControllerRepresentable {
    let onPick: ([String]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: CNContactPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onPick: ([String]) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let names = contacts.compactMap { contact -> String? in
                let name = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                return name.isEmpty ? nil : name
            }
            onPick(names)
        }

        func contactPickerDidCancel(_: CNContactPickerViewController) {
            onCancel()
        }
    }
}
