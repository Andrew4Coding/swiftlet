//
//  CategoryIconIntelligence.swift
//  Swiftlet
//

import Foundation
import FoundationModels

/// Uses Apple Intelligence's on-device language model to pick the SF Symbol that best fits a
/// category's name and description. Guided generation constrains the model to a curated symbol
/// set, so it can never return an invalid symbol name. Falls back to `CategorySymbolResolver`
/// (keyword matching) whenever the model is unavailable or errors.
enum CategoryIconIntelligence {
    /// The closed set of icons the model is allowed to choose from. `@Generable` turns each
    /// case into an allowed output value for guided generation.
    @Generable
    enum Icon: String, CaseIterable {
        case food, drink, groceries, transport, travel, shopping, bills, phone,
             entertainment, health, fitness, education, pet, home, family,
             salary, refund, gift, investment, savings, work, donation, tax, transfer, other

        var symbolName: String {
            switch self {
            case .food: "fork.knife"
            case .drink: "cup.and.saucer.fill"
            case .groceries: "cart.fill"
            case .transport: "car.fill"
            case .travel: "airplane"
            case .shopping: "bag.fill"
            case .bills: "doc.text.fill"
            case .phone: "iphone"
            case .entertainment: "gamecontroller.fill"
            case .health: "cross.case.fill"
            case .fitness: "figure.run"
            case .education: "book.fill"
            case .pet: "pawprint.fill"
            case .home: "house.fill"
            case .family: "person.2.fill"
            case .salary: "banknote.fill"
            case .refund: "arrow.uturn.backward.circle.fill"
            case .gift: "gift.fill"
            case .investment: "chart.line.uptrend.xyaxis"
            case .savings: "wallet.pass.fill"
            case .work: "briefcase.fill"
            case .donation: "heart.fill"
            case .tax: "percent"
            case .transfer: "arrow.left.arrow.right"
            case .other: "tag.fill"
            }
        }

        var emoji: String {
            switch self {
            case .food: "🍜"
            case .drink: "☕️"
            case .groceries: "🛒"
            case .transport: "🚗"
            case .travel: "🧳"
            case .shopping: "🛍️"
            case .bills: "🧾"
            case .phone: "📱"
            case .entertainment: "🎮"
            case .health: "💊"
            case .fitness: "🏋️"
            case .education: "🎓"
            case .pet: "🐾"
            case .home: "🏠"
            case .family: "👨‍👩‍👧"
            case .salary: "💰"
            case .refund: "↩️"
            case .gift: "🎁"
            case .investment: "📈"
            case .savings: "🐷"
            case .work: "💼"
            case .donation: "💝"
            case .tax: "🏛️"
            case .transfer: "🔁"
            case .other: "🏷️"
            }
        }

        var colorHex: String {
            switch self {
            case .food, .donation: "FF3B30"
            case .drink, .shopping, .home: "FF9500"
            case .groceries, .salary, .fitness: "34C759"
            case .transport, .phone, .transfer: "0A84FF"
            case .travel, .health: "00C7BE"
            case .bills, .tax: "D4C41A"
            case .entertainment, .education: "C644FC"
            case .pet, .family, .gift: "FF2D78"
            case .investment, .savings, .work, .refund: "3634E0"
            case .other: "8E8E93"
            }
        }
    }

    /// Curated SF Symbols offered in the manual icon picker.
    static let iconOptions: [String] = {
        var seen = Set<String>()
        let extras = [
            "creditcard.fill", "cart.fill", "fuelpump.fill", "tram.fill", "bicycle",
            "wineglass.fill", "birthday.cake.fill", "graduationcap.fill", "stethoscope",
            "hammer.fill", "wrench.and.screwdriver.fill", "wifi", "bolt.fill", "drop.fill",
            "gift.fill", "star.fill", "leaf.fill", "pawprint.fill", "figure.2.and.child.holdinghands",
            "dollarsign.circle.fill", "chart.pie.fill", "building.columns.fill", "shippingbox.fill",
            "ticket.fill", "cup.and.saucer.fill", "bag.fill", "questionmark.circle.fill",
        ]
        return (Icon.allCases.map(\.symbolName) + extras).filter { seen.insert($0).inserted }
    }()

    /// Whether the on-device model is ready to use right now.
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Best-effort icon suggestion — the keyword resolver's pick when Apple Intelligence can't
    /// be used.
    static func suggestIcon(
        name: String,
        scope: CategoryScope
    ) async -> Icon {
        let fallback = CategorySymbolResolver.icon(forName: name, scope: scope)

        guard SystemLanguageModel.default.availability == .available else { return fallback }

        let session = LanguageModelSession(instructions: """
        You choose the single icon that best represents a personal-finance category, \
        given its name. Consider what the user most likely spends \
        money on or receives money for. Answer with one icon only.
        """)

        let prompt = """
        Category name: \(name)
        Applies to: \(scope.displayName)
        """

        do {
            let response = try await session.respond(to: prompt, generating: Icon.self)
            return response.content
        } catch {
            return fallback
        }
    }
}
