//
//  EmailImportGuideView.swift
//  Swiftlet
//

import SwiftUI

struct EmailImportGuideView: View {
    private let steps: [LocalizedStringKey] = [
        "Open Shortcuts, go to Automation and tap New Automation.",
        "Choose Email and pick the bank's sender address, for example the BCA, BNI, OVO, Grab or GoPay receipt sender.",
        "Set it to Run Immediately.",
        "Add the Swiftlet action Import Bank Email.",
        "Set Email Text to the Email's Content, Sender to its Sender and Received Date to its Date Received.",
    ]

    private let providers: [(name: String, detail: LocalizedStringKey)] = [
        ("BCA", "QRIS payments from myBCA"),
        ("BNI", "wondr QRIS payments and e-wallet top-ups"),
        ("OVO", "Merchant payments"),
        ("Grab", "GrabFood and rides"),
        ("GoPay", "Gojek trips and GoTagihan bills"),
        ("QRIS", "Payments you receive as a merchant"),
    ]

    var body: some View {
        List {
            Section {
                Text("Swiftlet reads receipt emails with a Shortcuts automation and adds each one as a transaction. The email text is read on this device only.")
                    .foregroundStyle(.secondary)
            }

            Section("Set up") {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Label {
                        Text(step)
                    } icon: {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Supported emails") {
                ForEach(providers, id: \.name) { provider in
                    LabeledContent(provider.name) {
                        Text(provider.detail)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                Text("Each transaction goes into the wallet named like the bank or e-wallet, or your first wallet if none matches. The same email is never added twice.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Email Import")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { EmailImportGuideView() }
}
