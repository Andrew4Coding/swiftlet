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
                            .toolbar { cancelToolbarItem }
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
        .task { prepareDefaults() }
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
            CameraPicker { data in
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

    private var sourceStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                receiptPreview

                if viewModel.scanState == .scanning {
                    DSButton("Cancel scan", variant: .tertiary) { viewModel.cancelScan() }
                }

                VStack(spacing: 12) {
                    if CameraPicker.isAvailable {
                        DSButton("Scan receipt", systemImage: "camera.viewfinder") {
                            isPresentingCamera = true
                        }
                        .disabled(viewModel.scanState == .scanning)
                    }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose a photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.ds(.secondary))
                    .disabled(viewModel.scanState == .scanning)

                    DSButton("Enter manually", systemImage: "square.and.pencil", variant: .tertiary) {
                        path.append(.items)
                    }
                    .disabled(viewModel.scanState == .scanning)
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
                .overlay {
                    if viewModel.scanState == .scanning {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.black.opacity(0.45))
                        VStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Reading receipt…").font(.subheadline.weight(.medium)).foregroundStyle(.white)
                        }
                    }
                }
                .accessibilityLabel("Receipt photo")
        } else {
            DSSurface {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "receipt")
                        .font(.title)
                        .foregroundStyle(Color.ds(.accent))
                    Text("Scan the receipt and assign who had what.")
                        .dsTextStyle(.headline)
                    Text("Tax and service are shared fairly by what each person ordered.")
                        .dsTextStyle(.subheadline, color: .textSecondary)
                }
            }
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
