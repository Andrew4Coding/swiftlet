//
//  SplitBillEditorView.swift
//  Swiftlet
//

import PhotosUI
import SwiftData
import SwiftUI

struct SplitBillEditorView: View {
    enum Step: Hashable {
        case crop
        case items
        case people
        case review
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]
    @Query(sort: \TransactionCategory.sortIndex) private var allCategories: [TransactionCategory]

    @State private var viewModel = SplitBillViewModel()
    @State private var path: [Step] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var isConfirmingDiscard = false
    @State private var hasAutoOpenedCamera = false

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived }
    }

    private var categories: [TransactionCategory] {
        allCategories.filter { (CategoryScope(rawValue: $0.appliesToRaw) ?? .both).allows(.expense) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            sourceStep
                .navigationTitle("Split a bill")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(viewModel.scanState == .scanning ? .hidden : .automatic, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark", action: requestCancel)
                    }
                }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .crop:
                        if let pendingImage = viewModel.pendingImage {
                            ReceiptCropView(image: pendingImage) { cropped in
                                path.removeAll { $0 == .crop }
                                guard let data = ReceiptImage.compressedData(from: cropped) else { return }
                                Task { await runScan(data) }
                            }
                        }
                    case .items:
                        SplitItemsStepView(viewModel: viewModel) { path.append(.people) }
                            .toolbar { cancelToolbarItem }
                    case .people:
                        SplitPeopleStepView(viewModel: viewModel) { path.append(.review) }
                            .toolbar { cancelToolbarItem }
                    case .review:
                        SplitReviewStepView(
                            viewModel: viewModel,
                            wallets: wallets,
                            categories: categories,
                            onSave: save
                        )
                        .toolbar { cancelToolbarItem }
                    }
                }
        }
        .task {
            prepareDefaults()
            await openCameraOnFirstAppearance()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    startCropping(data)
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            ReceiptCameraView { data in
                isPresentingCamera = false
                if let data { startCropping(data) }
            }
        }
        .interactiveDismissDisabled(viewModel.isDirty)
        .confirmationDialog("Discard this split?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard split", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("What you entered will be lost.")
        }
    }

    @ViewBuilder
    private var sourceStep: some View {
        if viewModel.scanState == .scanning {
            processingStep
        } else {
            pickerStep
        }
    }

    private var processingStep: some View {
        VStack(spacing: 24) {
            if let data = viewModel.receiptImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Receipt photo")
            }
            HStack(spacing: 10) {
                ProgressView()
                Text("Reading receipt…").dsTextStyle(.subheadline, color: .textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds(.canvas))
    }

    private var pickerStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                receiptPreview

                VStack(spacing: 12) {
                    if ReceiptCameraView.isAvailable {
                        DSButton("Take photo", systemImage: "camera.viewfinder") {
                            isPresentingCamera = true
                        }
                    }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose a photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.ds(.secondary))

                    DSButton("Enter manually", systemImage: "square.and.pencil", variant: .tertiary) {
                        path.append(.items)
                    }
                }

                statusMessage

                Label("Receipts are read on your device and never uploaded.", systemImage: "lock.fill")
                    .dsTextStyle(.footnote, color: .textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(Color.ds(.canvas))
    }

    @ViewBuilder
    private var receiptPreview: some View {
        if let data = viewModel.receiptImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Receipt photo")
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if case let .failed(message) = viewModel.scanState {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .dsTextStyle(.subheadline, color: .warning)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ToolbarContentBuilder
    private var cancelToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Cancel", systemImage: "xmark", action: requestCancel)
        }
    }

    private func openCameraOnFirstAppearance() async {
        guard !hasAutoOpenedCamera, ReceiptCameraView.isAvailable else { return }
        hasAutoOpenedCamera = true
        try? await Task.sleep(for: .milliseconds(350))
        isPresentingCamera = true
    }

    private func startCropping(_ data: Data) {
        guard let image = ReceiptImage.upright(from: data) else { return }
        viewModel.pendingImage = image
        path.append(.crop)
    }

    private func requestCancel() {
        if viewModel.isDirty {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func runScan(_ data: Data) async {
        await viewModel.startScan(imageData: data)
        if case .finished = viewModel.scanState {
            path.append(.items)
        }
    }

    private func prepareDefaults() {
        if viewModel.wallet == nil {
            viewModel.wallet = wallets.first ?? WalletMigrator.ensureDefaultWallet(context: modelContext)
        }
        if viewModel.category == nil {
            viewModel.category = categories.first { $0.name.localizedCaseInsensitiveContains("food") } ?? categories.first
        }
    }

    private func save() {
        if viewModel.save(context: modelContext) != nil {
            dismiss()
        }
    }
}
