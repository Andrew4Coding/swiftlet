import Foundation
import FoundationModels
import Observation
import SwiftData

struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    enum State {
        case streaming
        case done
        case failed
    }

    let id = UUID()
    let role: Role
    var text: String
    var images: [Data] = []
    var state: State = .done
}

enum ChatAvailability: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceOff
    case modelNotReady
    case unknown

    init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available:
            self = .available
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible: self = .deviceNotEligible
            case .appleIntelligenceNotEnabled: self = .appleIntelligenceOff
            case .modelNotReady: self = .modelNotReady
            @unknown default: self = .unknown
            }
        }
    }

    var explanation: String {
        switch self {
        case .available: ""
        case .deviceNotEligible: "This iPhone doesn't support Apple Intelligence, so Ask Swiftlet isn't available."
        case .appleIntelligenceOff: "Turn on Apple Intelligence in Settings to ask questions about your money."
        case .modelNotReady: "The on-device model is still getting ready. Try again in a little while."
        case .unknown: "Ask Swiftlet isn't available right now."
        }
    }
}

@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isResponding = false
    private(set) var availability: ChatAvailability = ChatAvailability(SystemLanguageModel.default.availability)
    var input = ""

    private var source: ChatDataSource?
    private var session: LanguageModelSession?
    private var task: Task<Void, Never>?

    var canSend: Bool {
        availability == .available && !isResponding && !trimmedInput.isEmpty
    }

    var canRetry: Bool {
        !isResponding && messages.last?.state == .failed
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func configure(context: ModelContext) {
        refreshAvailability()
        if source == nil {
            source = ChatDataSource(context: context)
        }
    }

    func refreshAvailability() {
        availability = ChatAvailability(SystemLanguageModel.default.availability)
    }

    func send(_ suggestion: String? = nil) {
        let prompt = suggestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmedInput
        guard availability == .available, !isResponding, !prompt.isEmpty else { return }
        input = ""
        messages.append(ChatMessage(role: .user, text: prompt))
        respond(to: prompt)
    }

    func retry() {
        guard canRetry,
              let prompt = messages.dropLast().last(where: { $0.role == .user })?.text
        else { return }
        messages.removeLast()
        respond(to: prompt)
    }

    func newChat() {
        task?.cancel()
        task = nil
        session = nil
        messages = []
        isResponding = false
        input = ""
    }

    private func respond(to prompt: String) {
        let reply = ChatMessage(role: .assistant, text: "", state: .streaming)
        messages.append(reply)
        isResponding = true
        task = Task { [weak self] in
            await self?.run(prompt: prompt, replyID: reply.id)
        }
    }

    private func run(prompt: String, replyID: UUID) async {
        _ = source?.takeImages()
        do {
            do {
                try await stream(prompt: prompt, replyID: replyID)
            } catch let error as LanguageModelSession.GenerationError {
                guard case .exceededContextWindowSize = error else { throw error }
                restartSession(excluding: replyID, prompt: prompt)
                _ = source?.takeImages()
                update(replyID) { $0.text = "" }
                try await stream(prompt: prompt, replyID: replyID)
            }
            let images = source?.takeImages() ?? []
            update(replyID) {
                $0.images = images
                $0.state = .done
            }
        } catch is CancellationError {
            return
        } catch {
            update(replyID) {
                $0.state = .failed
                $0.text = String(localized: "Something went wrong. Try again.")
            }
        }
        isResponding = false
    }

    private func stream(prompt: String, replyID: UUID) async throws {
        guard let session = currentSession() else { throw CancellationError() }
        for try await snapshot in session.streamResponse(to: prompt) {
            try Task.checkCancellation()
            update(replyID) { $0.text = snapshot.content }
        }
    }

    private func currentSession() -> LanguageModelSession? {
        if session == nil, let source {
            session = ChatSessionFactory.make(source: source)
        }
        return session
    }

    private func restartSession(excluding replyID: UUID, prompt: String) {
        guard let source else { return }
        var turns = messages.filter { $0.id != replyID }
        if let last = turns.last, last.role == .user, last.text == prompt {
            turns.removeLast()
        }
        let history = ChatHistorySummary.make(
            turns.map { ChatHistorySummary.Turn(isUser: $0.role == .user, text: $0.text) }
        )
        session = ChatSessionFactory.make(source: source, history: history)
    }

    private func update(_ id: UUID, _ change: (inout ChatMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }
}
