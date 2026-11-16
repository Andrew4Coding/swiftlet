import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TransactionForm: View {
    enum Field: Hashable {
        case amount
        case title
    }

    @Bindable var viewModel: AddTransactionViewModel
    var showsReceipt = true
    var focusedField: FocusState<Field?>.Binding

    @Query(sort: \TransactionCategory.sortIndex) private var allCategories: [TransactionCategory]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived || $0.persistentModelID == viewModel.wallet?.persistentModelID }
    }

    var body: some View {
        Section {
            Picker("Type", selection: $viewModel.type) {
                ForEach(TransactionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.type) { _, _ in viewModel.typeDidChange() }

            TextField("Amount", text: $viewModel.amountText, prompt: Text("Rp 0"))
                .focused(focusedField, equals: .amount)
                .monospacedDigit()
                .onChange(of: viewModel.amountText) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits != newValue {
                        viewModel.amountText = digits
                    }
                }
            if viewModel.isDetectingAmount {
                Label("Reading receipt…", systemImage: "doc.text.viewfinder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if viewModel.amountDetectionTimedOut {
                Label("Amount not detected", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Title", text: $viewModel.title, prompt: Text(viewModel.type == .transfer ? "Transfer" : "What was it for?"))
                .focused(focusedField, equals: .title)
        }

        Section {
            Picker(viewModel.type == .income ? "To wallet" : "From wallet", selection: $viewModel.wallet) {
                Text("Choose…").tag(nil as Wallet?)
                ForEach(wallets) { wallet in
                    Text(wallet.name).tag(wallet as Wallet?)
                }
            }
            if viewModel.type == .transfer {
                Picker("To wallet", selection: $viewModel.destinationWallet) {
                    Text("Choose…").tag(nil as Wallet?)
                    ForEach(wallets.filter { $0.persistentModelID != viewModel.wallet?.persistentModelID }) { wallet in
                        Text(wallet.name).tag(wallet as Wallet?)
                    }
                }
            } else {
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("Choose…").tag(nil as TransactionCategory?)
                    ForEach(viewModel.availableCategories(from: allCategories)) { category in
                        Text("\(category.iconValue)  \(category.name)").tag(category as TransactionCategory?)
                    }
                }
            }
            DatePicker("Date", selection: $viewModel.date)
            TextField("Note", text: $viewModel.descriptionText, axis: .vertical)
                .lineLimit(1 ... 4)
        }

        if showsReceipt {
            Section("Receipt") {
                ReceiptField(viewModel: viewModel, categories: allCategories)
            }
        }
    }
}

struct ReceiptField: View {
    @Bindable var viewModel: AddTransactionViewModel
    let categories: [TransactionCategory]

    @State private var isTargeted = false
    @State private var isPicking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = viewModel.receiptImageData, let image = ReceiptImage.thumbnail(from: data, maxPixels: 600) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Receipt photo")
                HStack {
                    Button("Replace…") { isPicking = true }
                    Button("Remove", role: .destructive) { viewModel.receiptImageData = nil }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "doc.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Drop a receipt or payment screenshot, or paste one with ⌘V")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack {
                        Button("Choose…") { isPicking = true }
                        PasteButton(payloadType: Data.self) { items in
                            if let data = items.first {
                                Task { await ReceiptDetection.attach(data, to: viewModel, categories: categories) }
                            }
                        }
                        .labelStyle(.titleOnly)
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isTargeted ? Color.ds(.accent) : Color.ds(.border), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                )
            }
        }
        .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted) { providers in
            ReceiptDetection.load(from: providers) { data in
                await ReceiptDetection.attach(data, to: viewModel, categories: categories)
            }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.image]) { result in
            guard case let .success(url) = result else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                Task { await ReceiptDetection.attach(data, to: viewModel, categories: categories) }
            }
        }
    }
}

enum ReceiptDetection {
    /// Mirrors iOS: the same 2 s cap, the amount only when none is typed, the category only when none is chosen.
    static func attach(_ data: Data, to viewModel: AddTransactionViewModel, categories: [TransactionCategory]) async {
        guard let compressed = ReceiptImage.compressedData(from: data) else { return }
        viewModel.receiptImageData = compressed
        viewModel.amountDetectionTimedOut = false
        viewModel.isDetectingAmount = true
        let result = await PaymentProofReader.read(imageData: compressed, timeout: PaymentProofReader.detectionLimit)
        viewModel.isDetectingAmount = false
        guard let result, result.amount != nil || result.merchant != nil else {
            viewModel.amountDetectionTimedOut = true
            return
        }
        if let amount = result.amount, viewModel.amountText.isEmpty {
            viewModel.amountText = String(amount)
            viewModel.detectedAmount = amount
        } else if result.amount == nil {
            viewModel.amountDetectionTimedOut = true
        }
        if let merchant = result.merchant, viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.title = merchant
        }
        await viewModel.applyDetectedCategory(merchant: result.merchant, from: categories)
    }

    static func load(from providers: [NSItemProvider], perform: @escaping @MainActor (Data) async -> Void) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, let data = try? Data(contentsOf: url) else { return }
                Task { @MainActor in await perform(data) }
            }
            return true
        }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            _ = provider.loadDataRepresentation(for: .image) { data, _ in
                guard let data else { return }
                Task { @MainActor in await perform(data) }
            }
            return true
        }
        return false
    }
}
